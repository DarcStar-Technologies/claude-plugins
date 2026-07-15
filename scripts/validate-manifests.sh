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

  # Public (non-internal) plugins must appear in the marketplace catalog and
  # record which template they were scaffolded from.
  if [[ "$name" != _* ]]; then
    listed=0
    for dn in ${declared_names[@]+"${declared_names[@]}"}; do
      [[ "$dn" == "$name" ]] && listed=1 && break
    done
    [[ "$listed" -eq 1 ]] || fail "$name: not listed in marketplace.json"

    scaffold="$dir/.claude-plugin/scaffold.json"
    if [[ ! -f "$scaffold" ]]; then
      fail "$name: missing .claude-plugin/scaffold.json (scaffold via scripts/new-plugin.sh)"
    elif ! jq empty "$scaffold" 2>/dev/null; then
      fail "$name: scaffold.json is not valid JSON"
    elif [[ -z "$(jq -r '.template // empty' "$scaffold")" ]]; then
      fail "$name: scaffold.json missing 'template' field"
    fi
  fi
done < <(list_plugin_dirs all)

[[ "$errors" -eq 0 ]] || die "$errors manifest problem(s) found"
info "manifests OK"
