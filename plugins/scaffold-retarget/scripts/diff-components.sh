#!/usr/bin/env bash
# diff-components.sh — deterministic 3-way classification of a scaffolded plugin's
# component files for /scaffold-retarget, restricted to commands/ agents/ skills/ scripts/.
#
# Three inputs: the BASE template (the version the plugin was scaffolded from), the
# plugin's CURRENT files, and the TARGET template version. Because a template's files
# carry {{NAME}}/{{DESC}} placeholders while the plugin's files have them substituted,
# base/target are rendered with the plugin's OWN name/description before comparison.
#
# Per file (union of relative paths across the three), it emits one JSON object with a
# `class` (the 3-way relation) and a recommended `action`:
#   update    — base==current, target differs           (template advanced; you didn't touch it) -> take target
#   add       — only in target                          (new template file)                       -> add
#   delete    — base==current, absent in target         (template removed it; you didn't touch it) -> delete
#   keep      — target==base but current differs         (only you changed it)                     -> keep yours
#   unchanged — current already equals target                                                      -> nothing
#   conflict  — all three differ; OR you edited a file the template removed (conflict-removed);
#               OR you deleted a file the target still ships (conflict-deleted)               -> ASK
#   local-add — only in current (you added it)                                                     -> keep
# The command/planner decide what to do with a `conflict`; this script never picks a winner.
#
# Usage: diff-components.sh --base <dir> --current <plugin-dir> --target <dir> --name <n> --desc <d>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=plugins/scaffold-retarget/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

die() {
  printf 'diff-components: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

base="" current="" target="" name="" desc=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="${2:?}" && shift 2 ;;
    --current) current="${2:?}" && shift 2 ;;
    --target) target="${2:?}" && shift 2 ;;
    --name) name="${2:?}" && shift 2 ;;
    --desc) desc="${2-}" && shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done
[[ -d "$base" && -d "$current" && -n "$name" ]] ||
  die "usage: diff-components.sh --base <dir> --current <plugin-dir> --target <dir> --name <n> --desc <d>"
[[ -d "$target" ]] || die "target dir not found: $target"

COMPONENTS=(commands agents skills scripts)

# Content of <root>/<relpath> for comparison. Template files ($2 = "tmpl") are rendered
# with the plugin's identity via sr_render (lib/common.sh); the plugin's own files ($2 =
# "plugin") are read as-is. Both are captured in $(...), which strips a trailing newline,
# so comparison is newline-insensitive at EOF. Returns 1 when the file is absent (so an
# absent file is distinguishable from an empty one).
content() {
  local root="$1" kind="$2" rel="$3"
  local f="$root/$rel"
  [[ -f "$f" ]] || return 1
  if [[ "$kind" == "tmpl" ]]; then
    sr_render "$(cat "$f")" "$name" "$desc"
  else
    cat "$f"
  fi
}

# Union of relative component paths across the three trees.
list_rel() {
  local root="$1" comp
  for comp in "${COMPONENTS[@]}"; do
    [[ -d "$root/$comp" ]] || continue
    (cd "$root" && find "$comp" -type f 2>/dev/null)
  done
}
mapfile -t rels < <(
  {
    list_rel "$base"
    list_rel "$current"
    list_rel "$target"
  } | sort -u
)

results=()
for rel in ${rels[@]+"${rels[@]}"}; do
  [[ -n "$rel" ]] || continue
  cb="$(content "$base" tmpl "$rel")" && hb=1 || hb=0
  cc="$(content "$current" plugin "$rel")" && hc=1 || hc=0
  ct="$(content "$target" tmpl "$rel")" && ht=1 || ht=0

  class="" action=""
  if [[ "$hc" -eq 0 && "$ht" -eq 1 ]]; then
    if [[ "$hb" -eq 1 ]]; then
      # You deleted a file the target template still ships — don't silently resurrect it.
      class="conflict-deleted"
      action="conflict"
    else
      class="added-in-target"
      action="add"
    fi
  elif [[ "$hc" -eq 1 && "$ht" -eq 0 ]]; then
    if [[ "$hb" -eq 1 && "$cb" == "$cc" ]]; then
      class="removed-in-target"
      action="delete"
    elif [[ "$hb" -eq 0 ]]; then
      class="local-add"
      action="keep"
    else
      class="conflict-removed" # template removed a file you had customized
      action="conflict"
    fi
  elif [[ "$hc" -eq 1 && "$ht" -eq 1 ]]; then
    if [[ "$cc" == "$ct" ]]; then
      class="unchanged"
      action="none"
    elif [[ "$hb" -eq 1 && "$cb" == "$cc" ]]; then
      class="update"
      action="update" # template advanced; you didn't touch it
    elif [[ "$hb" -eq 1 && "$cb" == "$ct" ]]; then
      class="local-only"
      action="keep" # only you changed it
    else
      class="conflict"
      action="conflict" # both diverged
    fi
  else
    continue # present only in base -> irrelevant to current<->target
  fi
  results+=("$(jq -cn --arg p "$rel" --arg c "$class" --arg a "$action" '{path:$p, class:$c, action:$a}')")
done

if [[ "${#results[@]}" -eq 0 ]]; then
  printf '[]\n'
else
  printf '%s\n' "${results[@]}" | jq -s '.'
fi
