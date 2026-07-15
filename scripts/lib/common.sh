#!/usr/bin/env bash
# Shared helpers for repository automation scripts.
# Source it from a script that lives in scripts/:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/common.sh"
#
# Every script wants strict mode, so it is set here for callers too.
set -euo pipefail

# ---- Output helpers -------------------------------------------------------
if [[ -t 1 ]]; then
  _c_red=$'\033[31m'
  _c_grn=$'\033[32m'
  _c_ylw=$'\033[33m'
  _c_rst=$'\033[0m'
else
  _c_red='' _c_grn='' _c_ylw='' _c_rst=''
fi

info() { printf '%s==>%s %s\n' "$_c_grn" "$_c_rst" "$*"; }
warn() { printf '%swarn:%s %s\n' "$_c_ylw" "$_c_rst" "$*" >&2; }
err() { printf '%serror:%s %s\n' "$_c_red" "$_c_rst" "$*" >&2; }
die() {
  err "$*"
  exit 1
}

# ---- Environment ----------------------------------------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

# Repository root, derived from this library's location (scripts/lib/common.sh)
# rather than git, so the scripts work inside test fixtures and any checkout.
repo_root() {
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || return 1
  printf '%s\n' "$d"
}

plugins_dir() { printf '%s/plugins\n' "$(repo_root)"; }

# Print each plugin directory, one per line. Internal directories (prefixed
# with "_", e.g. _template) are skipped unless --all is given.
list_plugin_dirs() {
  local include_internal=0
  [[ "${1:-}" == "--all" ]] && include_internal=1
  local pdir base dir
  pdir="$(plugins_dir)"
  [[ -d "$pdir" ]] || return 0
  for dir in "$pdir"/*/; do
    [[ -d "$dir" ]] || continue
    base="$(basename "$dir")"
    if [[ "$base" == _* && "$include_internal" -eq 0 ]]; then
      continue
    fi
    printf '%s\n' "${dir%/}"
  done
}

# Return 0 if the argument is a valid semantic version (semver.org 2.0.0).
is_semver() {
  local re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  [[ "$1" =~ $re ]]
}
