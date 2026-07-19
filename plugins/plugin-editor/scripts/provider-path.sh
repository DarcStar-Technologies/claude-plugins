#!/usr/bin/env bash
# provider-path.sh — resolve a *provider plugin's* scripts directory at run time. A
# provider plugin (edit-kit, plan-kit, semver, …) owns deterministic scripts other
# plugins run rather than vendor; this is the one generic locator each consumer vendors to
# find one. (A bootstrap resolver can't itself be resolved by another provider —
# chicken-and-egg — so it is copied per consumer, not shared at run time; keeping ONE
# generic implementation, parameterized by provider name + required files, is the point.)
#
# Resolution precedence (mirrors $SEMVER_BIN and the older <name>-path.sh resolvers):
#   1. $<PROVIDER>_DIR                                   (explicit override; e.g. PLAN_KIT_DIR)
#   2. <marketplace-ancestor>/plugins/<provider>/scripts (walk up from the start-dir AND
#      from this script's own install location)
#   3. a directory on PATH holding the required files
# A candidate dir qualifies only if it holds EVERY required file, so a stray/partial
# install can't half-resolve into a mid-run "No such file or directory".
#
# Usage: provider-path.sh <provider-name> <required-file>... [--from <start-dir>]
#   provider-name   the provider plugin's name (its directory under plugins/)
#   required-file   one or more files the resolved dir must contain (e.g. validate-plan.sh)
#   --from <dir>    where to start the ancestor search (default: .)
#
# Prints the resolved scripts directory on success; exits non-zero (hint on stderr) otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  printf 'provider-path: %s\n' "$*" >&2
  exit 1
}

provider=""
start="."
required=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      [[ $# -ge 2 ]] || die "--from needs a value"
      start="$2"
      shift 2
      ;;
    --from=*)
      start="${1#--from=}"
      shift
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      if [[ -z "$provider" ]]; then
        provider="$1"
      else
        required+=("$1")
      fi
      shift
      ;;
  esac
done

[[ -n "$provider" ]] || die "usage: provider-path.sh <provider-name> <required-file>... [--from <dir>]"
[[ "${#required[@]}" -gt 0 ]] || die "at least one required file is needed"

# Env override var name: a provider's kebab name -> UPPER_SNAKE + _DIR (plan-kit -> PLAN_KIT_DIR).
env_var="$(printf '%s' "$provider" | tr 'a-z-' 'A-Z_')_DIR"

holds() { # <dir> -> 0 if <dir> holds every required file
  local dir="$1" f
  [[ -d "$dir" ]] || return 1
  for f in "${required[@]}"; do
    [[ -f "$dir/$f" ]] || return 1
  done
  return 0
}

# 1. explicit override (only if it actually holds the toolkit).
override="${!env_var:-}"
if [[ -n "$override" ]] && holds "${override%/}"; then
  printf '%s\n' "${override%/}"
  exit 0
fi

# 2. nearest marketplace ancestor's plugins/<provider>/scripts — search up from both the
#    caller's start-dir and this script's own location.
for anchor in "$start" "$SCRIPT_DIR"; do
  d="$(cd "$anchor" 2>/dev/null && pwd)" || continue
  while [[ -n "$d" ]]; do
    if holds "$d/plugins/$provider/scripts"; then
      printf '%s\n' "$d/plugins/$provider/scripts"
      exit 0
    fi
    [[ "$d" == "/" ]] && break
    d="$(dirname "$d")"
  done
done

# 3. a dir on PATH that holds the required files.
if on_path="$(command -v "${required[0]}" 2>/dev/null)"; then
  cand="$(cd "$(dirname "$on_path")" && pwd)"
  if holds "$cand"; then
    printf '%s\n' "$cand"
    exit 0
  fi
fi

die "$provider not found — install the $provider plugin, set $env_var, or put its scripts on PATH"
