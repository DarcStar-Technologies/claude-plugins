#!/usr/bin/env bash
# resolve-template-version.sh — materialize a SPECIFIC version (or "latest") of a
# reference template and print where its files live, for /scaffold-retarget's 3-way diff.
#
# Generalizes scaffold-upgrade/check-upgrade.sh's resolution (which only finds the
# LATEST) to fetch an arbitrary requested version. Resolution order:
#   1. an ancestor marketplace's templates/<name>, IF it holds the requested version
#      (for "latest": whatever version it holds);
#   2. a local path recorded in the plugin's scaffold.json `source`, same condition;
#   3. the template's <name>--v<ver> (or legacy <name>-v<ver>) release tag in the
#      recorded (or default) repo — the general path for any requested version.
#
# Usage:
#   resolve-template-version.sh <template> <version|latest> [--from <dir>] [--source <src>]
#
# Prints JSON: {template, version, dir, resolvedFrom, cleanupPath}
#   - dir         : absolute path to the materialized template dir (has .claude-plugin/plugin.json)
#   - cleanupPath : a throwaway clone root the CALLER must `rm -rf` when done, or null when
#                   `dir` is an existing in-repo/local dir that must NOT be deleted.
# Version math reuses the semver engine at run time ($SEMVER_BIN -> ancestor -> PATH).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="${SCAFFOLD_RETARGET_DEFAULT_REPO:-https://github.com/DarcStar-Technologies/claude-plugins.git}"

die() {
  printf 'resolve-template-version: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v git >/dev/null 2>&1 || die "git is required"

tmpl="${1:-}"
want="${2:-}"
[[ -n "$tmpl" && -n "$want" ]] ||
  die "usage: resolve-template-version.sh <template> <version|latest> [--from <dir>] [--source <src>]"
shift 2
from_dir="."
source_str=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) from_dir="${2:?--from needs a dir}" && shift 2 ;;
    --source) source_str="${2:?--source needs a value}" && shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

find_semver() {
  if [[ -n "${SEMVER_BIN:-}" && -x "${SEMVER_BIN:-}" ]]; then
    printf '%s' "$SEMVER_BIN"
    return 0
  fi
  local start d
  for start in "$from_dir" "$SCRIPT_DIR"; do
    d="$(cd "$start" 2>/dev/null && pwd)" || d=""
    while [[ -n "$d" && "$d" != "/" ]]; do
      [[ -x "$d/plugins/semver/scripts/semver.sh" ]] && {
        printf '%s' "$d/plugins/semver/scripts/semver.sh"
        return 0
      }
      d="$(dirname "$d")"
    done
  done
  command -v semver.sh 2>/dev/null && return 0
  return 1
}
semver="$(find_semver)" ||
  die "semver engine not found — install the semver plugin, put semver.sh on PATH, or set SEMVER_BIN"

[[ "$want" == "latest" ]] || "$semver" validate "$want" >/dev/null 2>&1 ||
  die "requested version is not valid semver: '$want' (use a version like 0.3.0, or 'latest')"

template_dir_in() {
  local root="$1" d
  for d in "$root/templates/$tmpl" "$root/$tmpl"; do
    [[ -f "$d/.claude-plugin/plugin.json" ]] && {
      printf '%s' "$d"
      return 0
    }
  done
  return 1
}
version_in() { jq -r '.version // empty' "$1/.claude-plugin/plugin.json"; }

# A materialized version matches the request when it equals <want> (or always, for latest).
matches() {
  [[ "$want" == "latest" ]] && return 0
  [[ "$("$semver" compare "$1" "$want")" == "0" ]]
}

emit() { # <content-dir> <version> <resolvedFrom> <cleanup-path-or-empty>
  jq -n --arg t "$tmpl" --arg v "$2" --arg d "$(cd "$1" && pwd)" --arg f "$3" --arg cp "$4" \
    '{template:$t, version:$v, dir:$d, resolvedFrom:$f, cleanupPath:(if $cp=="" then null else $cp end)}'
  exit 0
}

# 1. ancestor marketplace (in-repo; no network) — used when it holds the wanted version.
d="$(cd "$from_dir" 2>/dev/null && pwd)" || d=""
while [[ -n "$d" && "$d" != "/" ]]; do
  if [[ -f "$d/.claude-plugin/marketplace.json" ]] && td="$(template_dir_in "$d")"; then
    v="$(version_in "$td")"
    [[ -n "$v" ]] && matches "$v" && emit "$td" "$v" "marketplace:$d" ""
  fi
  d="$(dirname "$d")"
done

# 2. a local path recorded in the source, same condition.
case "$source_str" in
  local:* | repo:*)
    spec="${source_str#*:}"
    [[ "$source_str" == repo:* && "$spec" != *://* && "$spec" != *:*/* && "$spec" == *@* ]] && spec="${spec%@*}"
    if [[ -d "$spec" ]] && td="$(template_dir_in "$spec")"; then
      v="$(version_in "$td")"
      [[ -n "$v" ]] && matches "$v" && emit "$td" "$v" "local:$spec" ""
    fi
    ;;
esac

# 3. remote tags — clone the tag for the exact wanted version (or the highest, for latest).
url=""
case "$source_str" in
  tag:*) url="$DEFAULT_REPO" ;;
  default:*) url="${source_str#default:}" ;;
  repo:*)
    spec="${source_str#repo:}"
    [[ "$spec" != *://* && "$spec" != *:*/* && "$spec" == *@* ]] && spec="${spec%@*}"
    if [[ ! -d "$spec" && "$spec" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
      url="https://github.com/${spec}.git"
    else
      url="$spec"
    fi
    ;;
  "") url="$DEFAULT_REPO" ;; # no source recorded: try the default upstream
    # NOTE: no catch-all. A `local:` source must NOT fall back to cloning the public
    # default repo — a same-named public template would be the WRONG content for a fork.
esac

if [[ -n "$url" ]]; then
  best=""
  best_tag=""
  while IFS= read -r line; do
    ref="${line#*$'\t'}"
    case "$ref" in *'^{}') continue ;; esac
    tag="${ref#refs/tags/}"
    case "$tag" in
      "${tmpl}--v"*) v="${tag#"${tmpl}--v"}" ;;
      "${tmpl}-v"*) v="${tag#"${tmpl}-v"}" ;;
      *) continue ;;
    esac
    "$semver" validate "$v" >/dev/null 2>&1 || continue
    if [[ "$want" == "latest" ]]; then
      [[ -z "$best" || "$("$semver" compare "$v" "$best")" == "1" ]] && {
        best="$v"
        best_tag="$tag"
      }
    elif [[ "$("$semver" compare "$v" "$want")" == "0" ]]; then
      best="$v"
      best_tag="$tag"
      break
    fi
  done < <(git ls-remote --tags "$url" "refs/tags/${tmpl}--v*" "refs/tags/${tmpl}-v*" 2>/dev/null)
  if [[ -n "$best_tag" ]]; then
    tmp="$(mktemp -d)"
    if git clone --depth 1 --branch "$best_tag" -- "$url" "$tmp" >/dev/null 2>&1 && td="$(template_dir_in "$tmp")"; then
      emit "$td" "$best" "tags:$url@$best_tag" "$tmp"
    fi
    rm -rf "$tmp"
  fi
fi

die "could not resolve template '$tmpl' version '$want' (searched an ancestor marketplace, the recorded local source, and the ${tmpl}--v*/${tmpl}-v* tags of ${url:-<no repo>})"
