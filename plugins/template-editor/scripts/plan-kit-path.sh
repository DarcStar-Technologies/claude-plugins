#!/usr/bin/env bash
# plan-kit-path.sh — resolve the plan-kit provider's scripts directory, which this
# plugin's guided command calls at run time. plan-kit is a provider plugin (it owns the
# shared plan-shape validator), so this plugin NEVER vendors its validate-plan.sh — it
# locates the installed copy. Precedence mirrors edit-kit-path.sh / $SEMVER_BIN:
#   1. $PLAN_KIT_DIR                                     (explicit override)
#   2. <marketplace-ancestor>/plugins/plan-kit/scripts   (walk up from the start-dir
#      AND from this script's own install location)
#   3. a directory on PATH holding the toolkit
#
# A candidate directory qualifies only if it holds validate-plan.sh, so a stray/partial
# install can't half-resolve into a mid-run "No such file or directory". Prints the
# resolved scripts directory on success; exits non-zero (with a hint on stderr) otherwise.
#
# Usage: plan-kit-path.sh [start-dir]   (default: .)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
start="${1:-.}"

required=(validate-plan.sh)

has_plan_kit() { # <dir> -> 0 if <dir> holds the toolkit
  local dir="$1" s
  [[ -d "$dir" ]] || return 1
  for s in "${required[@]}"; do
    [[ -f "$dir/$s" ]] || return 1
  done
  return 0
}

# 1. explicit override (only if it actually holds the toolkit).
if [[ -n "${PLAN_KIT_DIR:-}" ]] && has_plan_kit "${PLAN_KIT_DIR%/}"; then
  printf '%s\n' "${PLAN_KIT_DIR%/}"
  exit 0
fi

# 2. nearest marketplace ancestor's plugins/plan-kit/scripts — search up from both the
#    caller's start-dir and this script's own location.
for anchor in "$start" "$SCRIPT_DIR"; do
  d="$(cd "$anchor" 2>/dev/null && pwd)" || continue
  while [[ -n "$d" ]]; do
    if has_plan_kit "$d/plugins/plan-kit/scripts"; then
      printf '%s\n' "$d/plugins/plan-kit/scripts"
      exit 0
    fi
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
done

# 3. a dir on PATH that holds the toolkit.
if on_path="$(command -v validate-plan.sh 2>/dev/null)"; then
  cand="$(cd "$(dirname "$on_path")" && pwd)"
  if has_plan_kit "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
fi

printf 'plan-kit-path: plan-kit not found — install the plan-kit plugin, set PLAN_KIT_DIR, or put its scripts on PATH\n' >&2
exit 1
