#!/usr/bin/env bash
# edit-kit-path.sh — resolve the edit-kit toolkit's scripts directory, which
# template-editor's command calls at run time (edit-kit is a provider plugin, so
# template-editor never vendors its scripts). Precedence, mirroring $SEMVER_BIN /
# $CHECK_UPGRADE_BIN:
#   1. $EDIT_KIT_DIR                                    (explicit override)
#   2. <marketplace-ancestor>/plugins/edit-kit/scripts  (walk up from the start-dir
#      AND from this script's own install location)
#   3. a directory on PATH holding the toolkit
#
# A candidate directory qualifies only if it holds EVERY script the caller relies
# on, so a stray/partial check-structure.sh can't half-resolve into a mid-housekeeping
# "No such file or directory". Prints the resolved scripts directory on success;
# exits non-zero (with a hint on stderr) otherwise.
#
# Usage: edit-kit-path.sh [start-dir]   (default: .)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
start="${1:-.}"

# Every script the command invokes — a candidate dir must contain all of them.
required=(check-structure.sh update-changelog.sh sync-version.sh scaffold-test.sh verify-repo.sh)

has_edit_kit() { # <dir> -> 0 if <dir> holds the whole toolkit
  local dir="$1" s
  [[ -d "$dir" ]] || return 1
  for s in "${required[@]}"; do
    [[ -f "$dir/$s" ]] || return 1
  done
  return 0
}

# 1. explicit override (only if it actually holds the toolkit).
if [[ -n "${EDIT_KIT_DIR:-}" ]] && has_edit_kit "${EDIT_KIT_DIR%/}"; then
  printf '%s\n' "${EDIT_KIT_DIR%/}"
  exit 0
fi

# 2. nearest marketplace ancestor's plugins/edit-kit/scripts — search up from both
#    the caller's start-dir and this script's own location.
for anchor in "$start" "$SCRIPT_DIR"; do
  d="$(cd "$anchor" 2>/dev/null && pwd)" || continue
  while [[ -n "$d" ]]; do
    if has_edit_kit "$d/plugins/edit-kit/scripts"; then
      printf '%s\n' "$d/plugins/edit-kit/scripts"
      exit 0
    fi
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
done

# 3. a dir on PATH that holds the whole toolkit.
if on_path="$(command -v check-structure.sh 2>/dev/null)"; then
  cand="$(cd "$(dirname "$on_path")" && pwd)"
  if has_edit_kit "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
fi

printf 'edit-kit-path: edit-kit not found — install the edit-kit plugin, set EDIT_KIT_DIR, or put its scripts on PATH\n' >&2
exit 1
