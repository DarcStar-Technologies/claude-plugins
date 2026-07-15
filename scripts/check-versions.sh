#!/usr/bin/env bash
# Validate that each plugin's version is valid semver and that its changelog
# follows Keep a Changelog structure with a matching or [Unreleased] section.
#
# Note: with Conventional Commits + release-please, contributors do NOT bump
# versions by hand — this checks structure and format, not that a bump landed.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_cmd jq

errors=0
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  name="$(basename "$dir")"
  manifest="$dir/.claude-plugin/plugin.json"
  changelog="$dir/CHANGELOG.md"

  if [[ ! -f "$manifest" ]]; then
    err "$name: missing plugin.json"
    errors=$((errors + 1))
    continue
  fi

  ver="$(jq -r '.version // empty' "$manifest")"
  if ! is_semver "$ver"; then
    err "$name: version '$ver' is not valid semver"
    errors=$((errors + 1))
  fi

  if [[ ! -f "$changelog" ]]; then
    err "$name: missing CHANGELOG.md"
    errors=$((errors + 1))
    continue
  fi

  if ! grep -qiE '^#[[:space:]]+changelog' "$changelog"; then
    err "$name: CHANGELOG.md missing '# Changelog' title"
    errors=$((errors + 1))
  fi

  # Accept an [Unreleased] section or a section for the current version.
  ver_escaped="${ver//./\\.}"
  if ! grep -qE "^##[[:space:]]+\[(Unreleased|${ver_escaped})\]" "$changelog"; then
    err "$name: CHANGELOG.md has no [Unreleased] or [$ver] section"
    errors=$((errors + 1))
  fi
done < <(list_plugin_dirs all)

[[ "$errors" -eq 0 ]] || die "$errors versioning problem(s) found"
info "versions & changelogs OK"
