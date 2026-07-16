#!/usr/bin/env bash
# discover-targets.sh — the DISCOVERY step of the plan-confirm-apply archetype.
# When the {{NAME}} command isn't given a target, it runs this to list candidate
# targets and emits JSON for the command's AskUserQuestion picker.
#
# Adapt the three markers below to your domain; the *shape* — walk up to a root
# marker, list candidate dirs under it, emit a JSON array of
# {name, path, description} — is what the command relies on. Each `path` is
# ABSOLUTE, so the command can use it regardless of its own working directory.
#
# Usage: discover-targets.sh [search-root]   (default: .)
#
# Exits 2 with no output when no root marker is found, so the caller can fall back
# to a free-text prompt. Prints `[]` (exit 0) when the root exists but holds no
# valid candidates.
set -euo pipefail

# --- adapt these to your domain -------------------------------------------
ROOT_MARKER="${ROOT_MARKER:-.git}"          # a file/dir that marks the project root
CANDIDATES_DIR="${CANDIDATES_DIR:-targets}" # dir under the root holding candidates
DESCRIPTOR="${DESCRIPTOR:-meta.json}"       # per-candidate JSON with .name / .description
# --------------------------------------------------------------------------

die() {
  printf 'discover-targets: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

root_arg="${1:-.}"

# Nearest ancestor containing $ROOT_MARKER (tests the filesystem root too).
find_root() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" ]]; do
    [[ -e "$d/$ROOT_MARKER" ]] && {
      printf '%s' "$d"
      return 0
    }
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
  return 1
}

root="$(find_root "$root_arg")" || exit 2 # no root marker -> caller falls back
[[ -d "$root/$CANDIDATES_DIR" ]] || {
  printf '[]\n'
  exit 0
}

# One jq per descriptor (validate + extract name/description together), then a
# single jq to assemble the array — instead of several forks per candidate.
entries=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  meta="$dir/$DESCRIPTOR"
  [[ -f "$meta" ]] || continue
  line="$(jq -r '[.name // "", .description // ""] | @tsv' "$meta" 2>/dev/null)" || continue
  name="${line%%$'\t'*}"
  desc="${line#*$'\t'}"
  [[ -n "$name" ]] || continue
  entries+=("$(printf '%s\t%s\t%s' "$name" "$desc" "$dir")") # path is absolute ($dir)
done < <(find "$root/$CANDIDATES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

[[ "${#entries[@]}" -gt 0 ]] || {
  printf '[]\n'
  exit 0
}
printf '%s\n' "${entries[@]}" |
  jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], path: .[2], description: .[1]})'
