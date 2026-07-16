#!/usr/bin/env bash
# update-changelog.sh — record a change in a plugin's CHANGELOG.md under
# `## [Unreleased]` -> `### <category>` (Keep a Changelog), creating the category
# subsection when it does not exist yet. It never touches the release-please
# version sections elsewhere in the file.
#
# Usage: update-changelog.sh <plugin-dir> <category> <bullet text...>
#   category: Added | Changed | Deprecated | Removed | Fixed | Security
set -euo pipefail

die() {
  printf 'update-changelog: %s\n' "$*" >&2
  exit 1
}

plugin_dir="${1:?usage: update-changelog.sh <plugin-dir> <category> <text...>}"
category="${2:-}"
[[ -n "$category" ]] || die "category required"
shift 2
bullet="$*"
[[ -n "$bullet" ]] || die "bullet text required"

case "$category" in
  Added | Changed | Deprecated | Removed | Fixed | Security) ;;
  *) die "category must be one of: Added Changed Deprecated Removed Fixed Security (got '$category')" ;;
esac

changelog="$plugin_dir/CHANGELOG.md"
[[ -f "$changelog" ]] || die "no CHANGELOG.md in $plugin_dir"
grep -qE '^##[[:space:]]+\[Unreleased\]' "$changelog" ||
  die "CHANGELOG.md has no '## [Unreleased]' section"

# Two-pass: read the file, locate the [Unreleased] range and the category within
# it, then reconstruct. Text is passed via the environment so awk's -v backslash
# processing can't mangle the bullet.
tmp="$(mktemp)"
CATEGORY="$category" BULLET="$bullet" awk '
  { line[NR] = $0 }
  END {
    cat = ENVIRON["CATEGORY"]; bullet = ENVIRON["BULLET"]; hdr = "### " cat
    n = NR
    us = 0
    for (i = 1; i <= n; i++) if (line[i] ~ /^##[[:space:]]+\[Unreleased\]/) { us = i; break }
    ue = n + 1
    for (i = us + 1; i <= n; i++) if (line[i] ~ /^##[[:space:]]/) { ue = i; break }
    ch = 0
    for (i = us + 1; i < ue; i++) if (line[i] == hdr) { ch = i; break }

    for (i = 1; i <= us; i++) print line[i]          # up to & incl. ## [Unreleased]

    if (ch > 0) {                                     # category exists: insert as first bullet
      for (i = us + 1; i <= ch; i++) print line[i]    # body up to & incl. the ### heading
      if (line[ch + 1] ~ /^[[:space:]]*$/) { print line[ch + 1]; print "- " bullet; start = ch + 2 }
      else { print "- " bullet; start = ch + 1 }
      for (i = start; i <= n; i++) print line[i]
    } else {                                          # category absent: create it first
      print ""; print hdr; print ""; print "- " bullet
      j = us + 1
      if (line[j] ~ /^[[:space:]]*$/) j++             # drop one existing blank to avoid a double
      if (j <= n) { print ""; for (i = j; i <= n; i++) print line[i] }  # separator only if content follows
    }
  }
' "$changelog" >"$tmp"
mv "$tmp" "$changelog"
printf 'recorded in %s: [Unreleased] > %s > %s\n' "$changelog" "$category" "$bullet"
