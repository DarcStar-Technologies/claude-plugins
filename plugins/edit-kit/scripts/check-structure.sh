#!/usr/bin/env bash
# check-structure.sh — validate a target directory's own plugin structure: its
# manifest fields + semver version, name vs. directory, the required docs, the
# changelog shape, and its scripts via shellcheck — never the whole repo. Works on
# any plugin-shaped directory (a published plugin OR a reference template).
#
# Part of the edit-kit toolkit — the domain-agnostic structural half of what was
# plugin-editor's check-template.sh (the template-lineage/drift half stays with
# plugin-editor, since it is specific to scaffolded plugins). Exits non-zero if the
# structural checks fail.
#
# Usage: check-structure.sh <target-dir>
set -euo pipefail

die() {
  printf 'check-structure: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

target_dir="${1:?usage: check-structure.sh <target-dir>}"
target_dir="${target_dir%/}"
[[ -d "$target_dir" ]] || die "directory not found: $target_dir"

status=0

printf '== structure ==\n'
errs=0
manifest="$target_dir/.claude-plugin/plugin.json"
if ! jq empty "$manifest" 2>/dev/null; then
  printf 'invalid or missing plugin.json\n'
  errs=1
else
  for field in name version description; do
    jq -e "has(\"$field\")" "$manifest" >/dev/null 2>&1 || {
      printf 'plugin.json missing field: %s\n' "$field"
      errs=1
    }
  done
  pname="$(jq -r '.name // empty' "$manifest")"
  [[ "$pname" == "$(basename "$target_dir")" ]] ||
    printf 'note: plugin.json name "%s" does not match directory "%s"\n' "$pname" "$(basename "$target_dir")"
  pver="$(jq -r '.version // empty' "$manifest")"
  [[ "$pver" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || {
    printf 'version "%s" is not valid semver\n' "$pver"
    errs=1
  }
fi
for f in CONTEXT.md CHANGELOG.md README.md; do
  [[ -f "$target_dir/$f" ]] || {
    printf 'missing %s\n' "$f"
    errs=1
  }
done
if [[ -f "$target_dir/CHANGELOG.md" ]]; then
  grep -qiE '^#[[:space:]]+changelog' "$target_dir/CHANGELOG.md" || {
    printf "CHANGELOG.md missing '# Changelog' title\n"
    errs=1
  }
  grep -qE '^##[[:space:]]+\[?(Unreleased|[0-9])' "$target_dir/CHANGELOG.md" || {
    printf "CHANGELOG.md has no [Unreleased] or version section\n"
    errs=1
  }
fi
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' sh; do
    shellcheck "$sh" || errs=1
  done < <(find "$target_dir" -name '*.sh' -print0 2>/dev/null)
fi
if [[ "$errs" -eq 0 ]]; then
  printf 'structure OK (target)\n'
else
  printf 'STRUCTURE CHECK FAILED\n'
  status=1
fi

exit "$status"
