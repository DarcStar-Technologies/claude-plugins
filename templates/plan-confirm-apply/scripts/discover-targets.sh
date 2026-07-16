#!/usr/bin/env bash
# discover-targets.sh — the DISCOVERY step of the plan-confirm-apply archetype.
# When the {{NAME}} command isn't given a target, it runs this to list candidate
# targets and emits JSON for the command's AskUserQuestion picker.
#
# Adapt the three markers below to your domain; the *shape* — walk up to a root
# marker, list candidate dirs under it, emit a JSON array of
# {name, path, description} — is what the command relies on.
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

# Nearest ancestor containing $ROOT_MARKER.
find_root() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/$ROOT_MARKER" ]] && {
      printf '%s' "$d"
      return 0
    }
    d="$(dirname "$d")"
  done
  return 1
}

root="$(find_root "$root_arg")" || exit 2 # no root marker -> caller falls back
[[ -d "$root/$CANDIDATES_DIR" ]] || {
  printf '[]\n'
  exit 0
}

out='[]'
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  meta="$dir/$DESCRIPTOR"
  [[ -f "$meta" ]] || continue
  jq empty "$meta" 2>/dev/null || continue # skip an unparseable descriptor, don't abort
  name="$(jq -r '.name // empty' "$meta")"
  [[ -n "$name" ]] || continue
  desc="$(jq -r '.description // ""' "$meta")"
  out="$(jq --arg n "$name" --arg p "$CANDIDATES_DIR/$(basename "$dir")" --arg d "$desc" \
    '. += [{name: $n, path: $p, description: $d}]' <<<"$out")"
done < <(find "$root/$CANDIDATES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

printf '%s\n' "$out"
