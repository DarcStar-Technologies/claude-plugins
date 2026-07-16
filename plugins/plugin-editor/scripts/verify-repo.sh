#!/usr/bin/env bash
# verify-repo.sh — post-apply verification for /edit-plugin. After edits are
# applied and semantically verified, confirm they didn't break the wider repo:
#   (1) REPO-WIDE — if this plugin lives in a marketplace checkout, run the repo's
#       scripts/check-all.sh (manifests + docs + versions).
#   (2) TOUCHED SCRIPTS — shellcheck any scripts/*.sh the edit changed.
#   (3) BATS — run the plugin's own scripts/tests/*.bats and the repo-root
#       scripts/tests/<name>.bats covering any touched script.
#
# Everything is best-effort and marketplace-aware: a missing check-all.sh (a
# standalone/portable plugin) or a missing shellcheck/bats is reported and skipped,
# NOT treated as a failure. Exits non-zero only when a check that actually ran
# failed, so the caller can stop before reporting the edit as done.
#
# Usage: verify-repo.sh <plugin-dir> [<file>...]
#   <file>... are paths (relative to <plugin-dir>) from the edit plan's files[].
set -euo pipefail

die() {
  printf 'verify-repo: %s\n' "$*" >&2
  exit 1
}

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

# Locate the marketplace root once (empty if none) — reused by sections 1 and 3.
mp_root="$(find_up "$plugin_dir" .claude-plugin/marketplace.json || true)"

# --- (1) repo-wide validation --------------------------------------------
printf '== repo-wide validation ==\n'
if [[ -n "$mp_root" && -f "$mp_root/scripts/check-all.sh" ]]; then
  printf 'running %s/scripts/check-all.sh\n' "$mp_root"
  if bash "$mp_root/scripts/check-all.sh"; then
    printf 'check-all.sh OK\n'
  else
    printf 'CHECK-ALL FAILED\n'
    status=1
  fi
else
  printf 'not in a marketplace repo (no scripts/check-all.sh found) — skipping repo-wide validation\n'
fi

# --- (2) touched scripts (shellcheck) ------------------------------------
printf '\n== touched scripts (shellcheck) ==\n'
touched_scripts=()
for rel in "$@"; do
  [[ -n "$rel" ]] || continue
  case "$rel" in
    scripts/*.sh) [[ -f "$plugin_dir/$rel" ]] && touched_scripts+=("$plugin_dir/$rel") ;;
  esac
done
if [[ "${#touched_scripts[@]}" -eq 0 ]]; then
  printf 'no touched scripts/*.sh to check\n'
elif ! command -v shellcheck >/dev/null 2>&1; then
  printf 'shellcheck not installed — skipping (informational)\n'
else
  for sh in "${touched_scripts[@]}"; do
    if shellcheck "$sh"; then
      printf 'shellcheck OK: %s\n' "$sh"
    else
      status=1
    fi
  done
fi

# --- (3) plugin bats tests -----------------------------------------------
printf '\n== plugin bats tests ==\n'
bats_files=()
# (a) tests the plugin bundles itself (portable plugins keep their own).
if [[ -d "$plugin_dir/scripts/tests" ]]; then
  while IFS= read -r -d '' b; do bats_files+=("$b"); done \
    < <(find "$plugin_dir/scripts/tests" -maxdepth 1 -name '*.bats' -print0 2>/dev/null)
fi
# (b) repo-root tests named for a touched script (this marketplace centralizes them).
if [[ -n "$mp_root" ]]; then
  for rel in "$@"; do
    case "$rel" in
      scripts/*.sh)
        cand="$mp_root/scripts/tests/$(basename "$rel" .sh).bats"
        [[ -f "$cand" ]] && bats_files+=("$cand")
        ;;
    esac
  done
fi
if [[ "${#bats_files[@]}" -gt 0 ]]; then
  mapfile -t bats_files < <(printf '%s\n' "${bats_files[@]}" | sort -u)
fi
if [[ "${#bats_files[@]}" -eq 0 ]]; then
  printf 'no bats tests found for this plugin or its touched scripts\n'
elif ! command -v bats >/dev/null 2>&1; then
  printf 'bats not installed — skipping (informational)\n'
else
  if bats "${bats_files[@]}"; then
    printf 'bats OK\n'
  else
    status=1
  fi
fi

exit "$status"
