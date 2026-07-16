#!/usr/bin/env bash
# check-template.sh — after editing a plugin, verify it still holds up:
#   (a) STRUCTURE — validate the TARGET plugin only (its manifest fields + semver
#       version, name vs. directory, the required docs, the changelog structure,
#       and its scripts via shellcheck) — never the whole repo.
#   (b) TEMPLATE LINEAGE — if the plugin was scaffolded from a template, reuse the
#       scaffold-upgrade plugin's check-upgrade.sh to report drift vs that template.
#
# check-upgrade.sh is resolved at run time (env override -> marketplace ancestor ->
# PATH), so nothing is vendored. Exits non-zero if the structural checks fail.
#
# Usage: check-template.sh <plugin-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() {
  printf 'check-template: %s\n' "$*" >&2
  exit 1
}

plugin_dir="${1:?usage: check-template.sh <plugin-dir>}"
plugin_dir="${plugin_dir%/}"
[[ -d "$plugin_dir" ]] || die "plugin directory not found: $plugin_dir"

status=0

# --- (a) structure — the TARGET plugin only, never the whole repo ---------
printf '== structure ==\n'
errs=0
manifest="$plugin_dir/.claude-plugin/plugin.json"
if ! jq empty "$manifest" 2>/dev/null; then
  printf 'invalid or missing plugin.json\n'
  errs=1
else
  for field in name version description; do
    jq -e "has(\"$field\")" "$manifest" >/dev/null 2>&1 || {
      printf 'plugin.json missing field: %s\n' "$field"
      errs=1
    }
  done
  pname="$(jq -r '.name // empty' "$manifest")"
  [[ "$pname" == "$(basename "$plugin_dir")" ]] ||
    printf 'note: plugin.json name "%s" does not match directory "%s"\n' "$pname" "$(basename "$plugin_dir")"
  pver="$(jq -r '.version // empty' "$manifest")"
  [[ "$pver" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || {
    printf 'version "%s" is not valid semver\n' "$pver"
    errs=1
  }
fi
for f in CONTEXT.md CHANGELOG.md README.md; do
  [[ -f "$plugin_dir/$f" ]] || {
    printf 'missing %s\n' "$f"
    errs=1
  }
done
if [[ -f "$plugin_dir/CHANGELOG.md" ]]; then
  grep -qiE '^#[[:space:]]+changelog' "$plugin_dir/CHANGELOG.md" || {
    printf "CHANGELOG.md missing '# Changelog' title\n"
    errs=1
  }
  grep -qE '^##[[:space:]]+\[?(Unreleased|[0-9])' "$plugin_dir/CHANGELOG.md" || {
    printf "CHANGELOG.md has no [Unreleased] or version section\n"
    errs=1
  }
fi
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' sh; do
    shellcheck "$sh" || errs=1
  done < <(find "$plugin_dir" -name '*.sh' -print0 2>/dev/null)
fi
if [[ "$errs" -eq 0 ]]; then
  printf 'structure OK (target plugin)\n'
else
  printf 'STRUCTURE CHECK FAILED\n'
  status=1
fi

# --- (b) template lineage / drift ----------------------------------------
printf '\n== template lineage ==\n'
if [[ ! -f "$plugin_dir/.claude-plugin/scaffold.json" ]]; then
  printf 'no template provenance (not scaffolded from a template) — skipping drift check\n'
else
  find_check_upgrade() {
    if [[ -n "${CHECK_UPGRADE_BIN:-}" && -x "${CHECK_UPGRADE_BIN:-}" ]]; then
      printf '%s' "$CHECK_UPGRADE_BIN"
      return 0
    fi
    local start d
    for start in "$plugin_dir" "$SCRIPT_DIR"; do
      d="$(cd "$start" 2>/dev/null && pwd)" || d=""
      while [[ -n "$d" && "$d" != "/" ]]; do
        [[ -x "$d/plugins/scaffold-upgrade/scripts/check-upgrade.sh" ]] && {
          printf '%s' "$d/plugins/scaffold-upgrade/scripts/check-upgrade.sh"
          return 0
        }
        d="$(dirname "$d")"
      done
    done
    command -v check-upgrade.sh 2>/dev/null && return 0
    return 1
  }
  if cu="$(find_check_upgrade)"; then
    "$cu" "$plugin_dir" || true # drift is informational; never fails the check
  else
    printf 'scaffold-upgrade check-upgrade.sh not found — install the scaffold-upgrade plugin or set CHECK_UPGRADE_BIN to report template drift\n'
  fi
fi

exit "$status"
