#!/usr/bin/env bash
# Validate the marketplace manifest and every plugin manifest:
#   - well-formed JSON
#   - required fields present
#   - plugin.json name matches its directory
#   - versions are valid semver
#   - every public plugin is listed in the marketplace, and every marketplace
#     source resolves to a real plugin directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_cmd jq

root="$(repo_root)"
marketplace="$root/.claude-plugin/marketplace.json"
errors=0
fail() {
  err "$*"
  errors=$((errors + 1))
}

# --- Marketplace manifest --------------------------------------------------
[[ -f "$marketplace" ]] || die "missing marketplace manifest: .claude-plugin/marketplace.json"
jq empty "$marketplace" 2>/dev/null || die "marketplace.json is not valid JSON"

for field in name plugins; do
  jq -e "has(\"$field\")" "$marketplace" >/dev/null 2>&1 ||
    fail "marketplace.json: missing required field '$field'"
done

declared_names=()
while IFS= read -r line; do declared_names+=("$line"); done \
  < <(jq -r '.plugins[]?.name // empty' "$marketplace")

# Every declared marketplace source must resolve to a plugin directory.
while IFS= read -r src; do
  [[ -n "$src" ]] || continue
  path="$root/${src#./}"
  [[ -d "$path" ]] || fail "marketplace source does not exist: $src"
  [[ -f "$path/.claude-plugin/plugin.json" ]] ||
    fail "marketplace source missing plugin.json: $src"
done < <(jq -r '.plugins[]?.source // empty' "$marketplace")

# Marketplace entries must not pin a version: plugin.json is the source of truth,
# and release-please only updates plugin.json — a version here would go stale.
while IFS= read -r pv; do
  [[ -n "$pv" ]] || continue
  fail "marketplace.json: plugin '$pv' must not pin a 'version' (plugin.json is the source of truth; it would drift)"
done < <(jq -r '.plugins[]? | select(has("version")) | .name // "(unnamed)"' "$marketplace")

# --- Per-plugin manifests --------------------------------------------------
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  name="$(basename "$dir")"
  manifest="$dir/.claude-plugin/plugin.json"

  [[ -f "$manifest" ]] || {
    fail "$name: missing .claude-plugin/plugin.json"
    continue
  }
  jq empty "$manifest" 2>/dev/null || {
    fail "$name: plugin.json is not valid JSON"
    continue
  }

  for field in name version description; do
    jq -e "has(\"$field\")" "$manifest" >/dev/null 2>&1 ||
      fail "$name: plugin.json missing required field '$field'"
  done

  pname="$(jq -r '.name // empty' "$manifest")"
  pver="$(jq -r '.version // empty' "$manifest")"

  [[ "$pname" == "$name" ]] ||
    fail "$name: plugin.json name '$pname' does not match directory '$name'"
  is_semver "$pver" || fail "$name: version '$pver' is not valid semver"

  # Public plugins (under plugins/) must appear in the marketplace catalog and
  # record which template they were scaffolded from. Templates (under templates/)
  # need neither.
  if ! is_template_dir "$dir"; then
    listed=0
    for dn in ${declared_names[@]+"${declared_names[@]}"}; do
      [[ "$dn" == "$name" ]] && listed=1 && break
    done
    [[ "$listed" -eq 1 ]] || fail "$name: not listed in marketplace.json"

    scaffold="$dir/.claude-plugin/scaffold.json"
    if [[ ! -f "$scaffold" ]]; then
      fail "$name: missing .claude-plugin/scaffold.json (scaffold with plugin-forge / forge-scaffold.sh)"
    elif ! jq empty "$scaffold" 2>/dev/null; then
      fail "$name: scaffold.json is not valid JSON"
    elif [[ -z "$(jq -r '.template // empty' "$scaffold")" ]]; then
      fail "$name: scaffold.json missing 'template' field"
    fi
  else
    # Templates carry a template.json manifest: identity fields + a cross-kind
    # `dependencies` list (dep-doctor descriptors). Its shared identity fields must
    # agree with plugin.json so the two manifests can't drift.
    tmanifest="$dir/template.json"
    if [[ ! -f "$tmanifest" ]]; then
      fail "$name: missing template.json (template manifest: metadata + cross-kind dependencies)"
    elif ! jq empty "$tmanifest" 2>/dev/null; then
      fail "$name: template.json is not valid JSON"
    else
      for field in name description author license keywords dependencies; do
        jq -e "has(\"$field\")" "$tmanifest" >/dev/null 2>&1 ||
          fail "$name: template.json missing required field '$field'"
      done
      tname="$(jq -r '.name // empty' "$tmanifest")"
      [[ "$tname" == "$name" ]] ||
        fail "$name: template.json name '$tname' does not match directory '$name'"
      # No drift: shared identity fields must equal plugin.json's.
      for field in name description license author; do
        jq -e -n --slurpfile a "$tmanifest" --slurpfile b "$manifest" --arg f "$field" \
          '$a[0][$f] == $b[0][$f]' >/dev/null 2>&1 ||
          fail "$name: template.json .$field does not match plugin.json .$field"
      done
      # dependencies: an array of {kind ∈ plugin|cli|library|mcp, name:<nonempty>} descriptors.
      if ! jq -e '.dependencies | type == "array"' "$tmanifest" >/dev/null 2>&1; then
        fail "$name: template.json .dependencies must be an array"
      elif ! jq -e '.dependencies | all(.[];
             (.kind | IN("plugin","cli","library","mcp")) and (.name | type == "string") and (.name | length > 0))' \
        "$tmanifest" >/dev/null 2>&1; then
        fail "$name: template.json .dependencies has an entry with an invalid 'kind' or missing/empty 'name'"
      fi
    fi
  fi
done < <(list_plugin_dirs all)

[[ "$errors" -eq 0 ]] || die "$errors manifest problem(s) found"
info "manifests OK"
