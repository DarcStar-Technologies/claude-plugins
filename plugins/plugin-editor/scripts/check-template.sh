#!/usr/bin/env bash
# check-template.sh — after editing a plugin, verify it still holds up:
#   (a) STRUCTURE — delegated to the edit-kit toolkit's check-structure.sh (resolved
#       via the sibling edit-kit-path.sh), so the structural rules live in ONE place
#       shared with template-editor rather than being duplicated here.
#   (b) TEMPLATE LINEAGE — if the plugin was scaffolded from a template, reuse the
#       scaffold-upgrade plugin's check-upgrade.sh to report drift vs that template.
#       This half is plugin-specific (a template has no upstream) and stays here.
#
# check-upgrade.sh and edit-kit are both resolved at run time (env override ->
# marketplace ancestor -> PATH), so nothing is vendored. Exits non-zero if the
# structural checks fail.
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

# --- (a) structure — delegated to edit-kit's check-structure.sh -----------
# A missing edit-kit doesn't gate the INDEPENDENT drift check below, so warn and
# continue (marking the run failed) rather than aborting and dropping the drift report.
if ek="$("$SCRIPT_DIR/edit-kit-path.sh" "$plugin_dir" 2>/dev/null)"; then
  "$ek/check-structure.sh" "$plugin_dir" || status=1
else
  printf 'WARNING: structure check skipped — edit-kit not found (install the edit-kit plugin or set EDIT_KIT_DIR). Continuing with the template-drift check.\n' >&2
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
