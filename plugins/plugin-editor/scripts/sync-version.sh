#!/usr/bin/env bash
# sync-version.sh — advance a plugin's version the right way for its context.
#
#   - release-please-managed (an ancestor release-please-config.json lists this
#     plugin's path as a package): do NOT hand-edit plugin.json — report that a
#     Conventional Commit plus the [Unreleased] CHANGELOG entry are what drive the
#     bump, and print the matching commit type.
#   - standalone: hand-bump plugin.json's version via the semver plugin's engine
#     (resolved at run time: $SEMVER_BIN -> marketplace ancestor -> PATH).
#
# Usage: sync-version.sh <plugin-dir> [major|minor|patch]   (default: patch)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
die() {
  printf 'sync-version: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

plugin_dir="${1:?usage: sync-version.sh <plugin-dir> [major|minor|patch]}"
plugin_dir="${plugin_dir%/}"
level="${2:-patch}"
case "$level" in
  major | minor | patch) ;;
  *) die "level must be major, minor, or patch (got '$level')" ;;
esac
manifest="$plugin_dir/.claude-plugin/plugin.json"
[[ -f "$manifest" ]] || die "no .claude-plugin/plugin.json in $plugin_dir"

find_up() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/$2" ]] && {
      printf '%s' "$d"
      return 0
    }
    d="$(dirname "$d")"
  done
  return 1
}

# --- release-please management? -------------------------------------------
managed=0
pkg=""
if cfg_root="$(find_up "$plugin_dir" release-please-config.json)"; then
  plugin_abs="$(cd "$plugin_dir" && pwd)"
  rel="${plugin_abs#"$cfg_root"/}"
  if jq -e --arg p "$rel" '(.packages // {}) | has($p)' "$cfg_root/release-please-config.json" >/dev/null 2>&1; then
    managed=1
    pkg="$rel"
  fi
fi

if [[ "$managed" -eq 1 ]]; then
  case "$level" in
    major) hint='feat(<scope>)!: <subject>   # or add a "BREAKING CHANGE:" footer' ;;
    minor) hint='feat(<scope>): <subject>' ;;
    patch) hint='fix(<scope>): <subject>' ;;
  esac
  printf 'release-please manages this plugin (package: %s) — do NOT hand-edit the version.\n' "$pkg"
  printf 'Land a Conventional Commit and release-please will bump plugin.json and write the release notes:\n'
  printf '  %s\n' "$hint"
  printf 'The [Unreleased] CHANGELOG entry you added is the human-readable record until then.\n'
  exit 0
fi

# --- standalone: hand-bump via the semver engine --------------------------
find_semver() {
  if [[ -n "${SEMVER_BIN:-}" && -x "${SEMVER_BIN:-}" ]]; then
    printf '%s' "$SEMVER_BIN"
    return 0
  fi
  local start d
  for start in "$plugin_dir" "$SCRIPT_DIR"; do
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

cur="$(jq -r '.version // empty' "$manifest")"
[[ -n "$cur" ]] || die "plugin.json has no version"
new="$("$semver" bump "$level" "$cur")"
tmp="$(mktemp)"
jq --arg v "$new" '.version = $v' "$manifest" >"$tmp" && mv "$tmp" "$manifest"
printf 'standalone plugin: bumped %s %s -> %s (%s)\n' "$(basename "$plugin_dir")" "$cur" "$new" "$level"
