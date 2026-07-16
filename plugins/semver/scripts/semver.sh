#!/usr/bin/env bash
# semver.sh — deterministic Semantic Versioning 2.0.0 operations.
#
# Self-contained (no dependencies beyond bash + git for `next`). Usable directly,
# by the /semver command, or sourced by other scripts.
#
# Usage:
#   semver.sh validate <v>              exit 0 if <v> is valid semver, else 1
#   semver.sh compare <a> <b>           print -1 | 0 | 1  (precedence of a vs b)
#   semver.sh bump <major|minor|patch> <v>   print the incremented version
#   semver.sh major|minor|patch <v>     print that core component
#   semver.sh diff <a> <b>              print major|minor|patch|prerelease|none
#   semver.sh next <current> <git-range>     next version from Conventional
#                                            Commits in <git-range> (e.g. v1.0.0..HEAD)
#
# Precedence follows semver.org: numeric core compared numerically; a version
# without a pre-release outranks one with; pre-release identifiers compared
# per spec; build metadata (+...) is ignored.
set -euo pipefail

_SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

die() {
  printf 'semver: %s\n' "$*" >&2
  exit 2
}

is_valid() { [[ "$1" =~ $_SEMVER_RE ]]; }

# Strip build metadata, then split into core + pre-release.
_core() {
  local v="${1%%+*}"
  printf '%s' "${v%%-*}"
}
_prerelease() {
  local v="${1%%+*}"
  [[ "$v" == *-* ]] && printf '%s' "${v#*-}"
}
_field() { # _field <0|1|2> <version>
  local core
  core="$(_core "$2")"
  local -a f
  IFS=. read -r -a f <<<"$core"
  printf '%s' "${f[$1]:-0}"
}

# Compare two pre-release identifier strings. Echoes -1 | 0 | 1.
_compare_prerelease() {
  local a="$1" b="$2"
  # No pre-release outranks a pre-release.
  [[ -z "$a" && -z "$b" ]] && {
    echo 0
    return
  }
  [[ -z "$a" ]] && {
    echo 1
    return
  }
  [[ -z "$b" ]] && {
    echo -1
    return
  }
  local -a ap bp
  IFS=. read -r -a ap <<<"$a"
  IFS=. read -r -a bp <<<"$b"
  local n=${#ap[@]} i x y
  ((${#bp[@]} > n)) && n=${#bp[@]}
  for ((i = 0; i < n; i++)); do
    x="${ap[i]-}"
    y="${bp[i]-}"
    # Fewer identifiers => lower precedence.
    [[ -z "$x" ]] && {
      echo -1
      return
    }
    [[ -z "$y" ]] && {
      echo 1
      return
    }
    [[ "$x" == "$y" ]] && continue
    if [[ "$x" =~ ^[0-9]+$ && "$y" =~ ^[0-9]+$ ]]; then
      if ((10#$x > 10#$y)); then
        echo 1
        return
      else
        echo -1
        return
      fi
    elif [[ "$x" =~ ^[0-9]+$ ]]; then
      echo -1
      return # numeric < alphanumeric
    elif [[ "$y" =~ ^[0-9]+$ ]]; then
      echo 1
      return
    elif [[ "$x" > "$y" ]]; then
      echo 1
      return
    else
      echo -1
      return
    fi
  done
  echo 0
}

semver_compare() {
  local a="$1" b="$2" i av bv
  for i in 0 1 2; do
    av="$(_field "$i" "$a")"
    bv="$(_field "$i" "$b")"
    if ((av > bv)); then
      echo 1
      return
    fi
    if ((av < bv)); then
      echo -1
      return
    fi
  done
  _compare_prerelease "$(_prerelease "$a")" "$(_prerelease "$b")"
}

semver_diff() {
  local a="$1" b="$2" i
  local names=(major minor patch)
  for i in 0 1 2; do
    if [[ "$(_field "$i" "$a")" != "$(_field "$i" "$b")" ]]; then
      echo "${names[$i]}"
      return
    fi
  done
  if [[ "$(_prerelease "$a")" != "$(_prerelease "$b")" ]]; then
    echo "prerelease"
  else
    echo "none"
  fi
}

semver_bump() {
  local level="$1" v="$2" maj min pat
  maj="$(_field 0 "$v")"
  min="$(_field 1 "$v")"
  pat="$(_field 2 "$v")"
  case "$level" in
    major) printf '%s.0.0\n' "$((maj + 1))" ;;
    minor) printf '%s.%s.0\n' "$maj" "$((min + 1))" ;;
    patch) printf '%s.%s.%s\n' "$maj" "$min" "$((pat + 1))" ;;
    *) die "bump level must be major, minor, or patch (got '$level')" ;;
  esac
}

# Highest bump implied by Conventional Commits in a git range: major|minor|patch|none.
semver_bump_level() {
  local range="$1" subjects level="none"
  command -v git >/dev/null 2>&1 || die "git is required for 'next'"
  # A breaking change (! before : or a BREAKING CHANGE footer) => major.
  if git log --format='%s' "$range" 2>/dev/null | grep -qE '^[a-zA-Z]+(\([^)]*\))?!:' ||
    git log --format='%B' "$range" 2>/dev/null | grep -qE '^BREAKING[ -]CHANGE:'; then
    echo "major"
    return
  fi
  subjects="$(git log --format='%s' "$range" 2>/dev/null || true)"
  if printf '%s\n' "$subjects" | grep -qE '^feat(\([^)]*\))?:'; then
    level="minor"
  elif printf '%s\n' "$subjects" | grep -qE '^fix(\([^)]*\))?:'; then
    level="patch"
  fi
  echo "$level"
}

# --- dispatch --------------------------------------------------------------
cmd="${1:-}"
[[ -n "$cmd" ]] || die "usage: semver.sh <validate|compare|bump|major|minor|patch|diff|next> ..."
shift

case "$cmd" in
  validate)
    [[ $# -eq 1 ]] || die "usage: semver.sh validate <version>"
    if is_valid "$1"; then
      printf 'valid: %s\n' "$1"
    else
      printf 'invalid: %s\n' "$1"
      exit 1
    fi
    ;;
  compare)
    [[ $# -eq 2 ]] || die "usage: semver.sh compare <a> <b>"
    is_valid "$1" || die "not valid semver: $1"
    is_valid "$2" || die "not valid semver: $2"
    semver_compare "$1" "$2"
    ;;
  diff)
    [[ $# -eq 2 ]] || die "usage: semver.sh diff <a> <b>"
    is_valid "$1" || die "not valid semver: $1"
    is_valid "$2" || die "not valid semver: $2"
    semver_diff "$1" "$2"
    ;;
  bump)
    [[ $# -eq 2 ]] || die "usage: semver.sh bump <major|minor|patch> <version>"
    is_valid "$2" || die "not valid semver: $2"
    semver_bump "$1" "$2"
    ;;
  major | minor | patch)
    [[ $# -eq 1 ]] || die "usage: semver.sh $cmd <version>"
    is_valid "$1" || die "not valid semver: $1"
    case "$cmd" in
      major) printf '%s\n' "$(_field 0 "$1")" ;;
      minor) printf '%s\n' "$(_field 1 "$1")" ;;
      patch) printf '%s\n' "$(_field 2 "$1")" ;;
    esac
    ;;
  next)
    [[ $# -eq 2 ]] || die "usage: semver.sh next <current-version> <git-range>"
    is_valid "$1" || die "not valid semver: $1"
    level="$(semver_bump_level "$2")"
    if [[ "$level" == "none" ]]; then
      printf '%s\n' "$1" # nothing releasable; unchanged
    else
      semver_bump "$level" "$1"
    fi
    ;;
  *) die "unknown command: $cmd" ;;
esac
