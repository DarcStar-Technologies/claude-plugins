#!/usr/bin/env bash
# discover-templates.sh — the DISCOVERY step for template-editor's picker when no
# target template is given. Resolves the marketplace root (nearest ancestor with
# .claude-plugin/marketplace.json), runs its scripts/list-templates.sh --json to
# list the reference templates under templates/, and emits a JSON array of
# {name, path, description} with an ABSOLUTE path (<root>/templates/<name>) so the
# command can use it regardless of its own working directory.
#
# Usage: discover-templates.sh [search-root]   (default: .)
#
# Exits 2 with no output when no marketplace ancestor is found, so the caller can
# fall back to a free-text prompt. Prints `[]` (exit 0) when there are no templates.
set -euo pipefail

die() {
  printf 'discover-templates: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

root_arg="${1:-.}"

# Nearest ancestor that is a marketplace (tests the filesystem root too).
find_marketplace() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" ]]; do
    [[ -f "$d/.claude-plugin/marketplace.json" ]] && {
      printf '%s' "$d"
      return 0
    }
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
  return 1
}

root="$(find_marketplace "$root_arg")" || exit 2 # no marketplace -> caller falls back
lt="$root/scripts/list-templates.sh"
[[ -x "$lt" ]] || {
  printf '[]\n'
  exit 0
}

# list-templates.sh --json emits [{name, version, description}]; add an absolute path.
# A genuine FAILURE of list-templates.sh is surfaced (exit 1, stderr) rather than
# masked as the benign `[]` "no templates" signal.
if ! out="$("$lt" --json 2>/dev/null)"; then
  die "the marketplace's list-templates.sh failed — run it directly to see why"
fi
[[ -n "$out" ]] || {
  printf '[]\n'
  exit 0
}
printf '%s' "$out" |
  jq --arg root "$root" 'map({name: .name, path: ($root + "/templates/" + .name), description: .description})'
