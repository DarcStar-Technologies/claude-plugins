#!/usr/bin/env bash
# verify-repo.sh — part of the edit-kit toolkit (resolved at run time by
# plugin-editor and template-editor). Post-apply cross-checks for the calling edit
# command. check-structure.sh already hard-validates the edited target's own
# structure and shellchecks its scripts; this adds two checks that the edit didn't
# break things BEYOND the target's own files. Because the calling command only ever
# edits inside the target dir, a failure that isn't fixable in-bounds must NOT
# falsely block a correct edit — so those parts are advisory:
#
#   (1) REPO-WIDE (advisory) — in a marketplace, run scripts/check-all.sh and relay
#       it. A repo-wide failure is either the target's own structure (already
#       hard-checked by check-structure.sh) or pre-existing breakage ELSEWHERE in
#       the repo, so this WARNS rather than fails.
#   (2) TESTS —
#       (a) the target's OWN bundled scripts/tests/*.bats (in-bounds, fixable) —
#           a failure here IS a hard failure (exit non-zero).
#       (b) the repo's centralized scripts/tests/<name>.bats for a touched script
#           that still exists (these live OUTSIDE the target dir, which the flow may
#           not edit) — advisory: warns on failure (e.g. a behavior change needs a
#           follow-up test update), never blocks.
#
# A marketplace not found, a missing check-all.sh, or bats not installed are all
# reported and skipped — never failures. Exits non-zero ONLY when the plugin's own
# bundled tests fail, so the caller stops only on a genuinely fixable break.
#
# Usage: verify-repo.sh <plugin-dir> [<file>...]
#   <file>... are paths from the edit plan's files[] (plugin-relative, ./-prefixed,
#   or repo-relative — all normalized).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/plan-paths.sh
. "$SCRIPT_DIR/lib/plan-paths.sh"

die() {
  printf 'verify-repo: %s\n' "$*" >&2
  exit 1
}
warn() { printf 'WARNING: %s\n' "$*"; }

plugin_dir="${1:?usage: verify-repo.sh <plugin-dir> [<file>...]}"
shift
plugin_dir="${plugin_dir%/}"
[[ -d "$plugin_dir" ]] || die "plugin directory not found: $plugin_dir"

status=0

find_up() { # <start-dir> <relpath> -> prints the nearest ancestor containing relpath
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/$2" ]] && {
      printf '%s' "$d"
      return 0
    }
    d="$(dirname "$d")"
  done
  return 1
}

# norm_rel (plan-path normalization) is shared with scaffold-test.sh via
# lib/plan-paths.sh, sourced above.

# Locate the marketplace root once (empty if none) — reused by sections 1 and 2.
mp_root="$(find_up "$plugin_dir" .claude-plugin/marketplace.json || true)"

# --- (1) repo-wide validation (advisory) ---------------------------------
printf '== repo-wide validation (advisory) ==\n'
if [[ -z "$mp_root" ]]; then
  printf 'not in a marketplace repo — skipping repo-wide validation\n'
elif [[ ! -f "$mp_root/scripts/check-all.sh" ]]; then
  printf 'marketplace found but scripts/check-all.sh is missing — skipping repo-wide validation\n'
else
  printf 'running %s/scripts/check-all.sh\n' "$mp_root"
  if bash "$mp_root/scripts/check-all.sh"; then
    printf 'check-all.sh OK\n'
  else
    warn "repo-wide checks failed. The calling command only edits inside the target dir, so this is either the target's own structure (already reported by check-structure.sh) or PRE-EXISTING breakage elsewhere in the repo — review before merging. Not blocking this edit."
  fi
fi

# --- (2) tests -----------------------------------------------------------
printf '\n== tests ==\n'
bundled=() # (a) the plugin's own tests — in-bounds, so a failure is hard.
central=() # (b) repo-root tests for a touched script — out-of-bounds, so advisory.
if [[ -d "$plugin_dir/scripts/tests" ]]; then
  while IFS= read -r -d '' b; do bundled+=("$b"); done \
    < <(find "$plugin_dir/scripts/tests" -maxdepth 1 -name '*.bats' -print0 2>/dev/null)
fi
if [[ -n "$mp_root" ]]; then
  for arg in "$@"; do
    [[ -n "$arg" ]] || continue
    rel="$(norm_rel "$plugin_dir" "$arg")"
    case "$rel" in
      scripts/*.sh)
        # A removed script has no behavior left to test — skip its centralized test.
        [[ -f "$plugin_dir/$rel" ]] || continue
        cand="$mp_root/scripts/tests/$(basename "$rel" .sh).bats"
        [[ -f "$cand" ]] && central+=("$cand")
        ;;
    esac
  done
fi
[[ "${#bundled[@]}" -gt 0 ]] && mapfile -t bundled < <(printf '%s\n' "${bundled[@]}" | sort -u)
[[ "${#central[@]}" -gt 0 ]] && mapfile -t central < <(printf '%s\n' "${central[@]}" | sort -u)

if [[ "${#bundled[@]}" -eq 0 && "${#central[@]}" -eq 0 ]]; then
  printf 'no bats tests found for this plugin or its touched scripts\n'
elif ! command -v bats >/dev/null 2>&1; then
  printf 'bats not installed — skipping (informational)\n'
else
  if [[ "${#bundled[@]}" -gt 0 ]]; then
    if bats "${bundled[@]}"; then
      printf 'bundled bats OK\n'
    else
      printf 'BUNDLED BATS FAILED\n'
      status=1
    fi
  fi
  if [[ "${#central[@]}" -gt 0 ]]; then
    if bats "${central[@]}"; then
      printf 'centralized bats OK\n'
    else
      warn "a repo-root test for a touched script failed. These tests live outside the target dir (scripts/tests/), which the calling command may not edit — if your change altered a script's behavior, update the matching test as a FOLLOW-UP. Not blocking this edit."
    fi
  fi
fi

exit "$status"
