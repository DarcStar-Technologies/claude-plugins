#!/usr/bin/env bash
# edit-kit-path.sh — resolve the edit-kit toolkit's scripts directory, which
# template-editor's command calls at run time (edit-kit is a provider plugin, so
# template-editor never vendors its scripts). Precedence, mirroring $SEMVER_BIN /
# $CHECK_UPGRADE_BIN:
#   1. $EDIT_KIT_DIR                                    (explicit override)
#   2. <marketplace-ancestor>/plugins/edit-kit/scripts  (walk up from [start-dir])
#   3. a directory on PATH containing check-structure.sh
#
# Prints the resolved scripts directory on success; exits non-zero (with a hint on
# stderr) if edit-kit can't be found.
#
# Usage: edit-kit-path.sh [start-dir]   (default: .)
set -euo pipefail

start="${1:-.}"
sentinel="check-structure.sh" # a script unique to edit-kit

if [[ -n "${EDIT_KIT_DIR:-}" && -f "${EDIT_KIT_DIR%/}/$sentinel" ]]; then
  printf '%s\n' "${EDIT_KIT_DIR%/}"
  exit 0
fi

d="$(cd "$start" 2>/dev/null && pwd)" || d=""
while [[ -n "$d" ]]; do
  if [[ -f "$d/plugins/edit-kit/scripts/$sentinel" ]]; then
    printf '%s\n' "$d/plugins/edit-kit/scripts"
    exit 0
  fi
  [[ "$d" == "/" ]] && break
  d="$(dirname "$d")"
done

if on_path="$(command -v "$sentinel" 2>/dev/null)"; then
  printf '%s\n' "$(cd "$(dirname "$on_path")" && pwd)"
  exit 0
fi

printf 'edit-kit-path: edit-kit not found — install the edit-kit plugin, set EDIT_KIT_DIR, or put its scripts on PATH\n' >&2
exit 1
