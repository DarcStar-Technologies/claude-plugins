#!/usr/bin/env bats
#
# Tests for plugin-editor/scripts/update-changelog.sh.

load helpers

setup() {
  SC="$(repo_root_dir)/plugins/plugin-editor/scripts/update-changelog.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/p"
  cat >"$FIX/p/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Added

- initial

## [0.1.0](x) (2026-01-01)

### Features

* released thing
MD
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "inserts a bullet at the top of an existing category" {
  run "$SC" "$FIX/p" Added "new feature"
  [ "$status" -eq 0 ]
  local nf ini
  nf=$(grep -n '^- new feature$' "$FIX/p/CHANGELOG.md" | cut -d: -f1)
  ini=$(grep -n '^- initial$' "$FIX/p/CHANGELOG.md" | cut -d: -f1)
  [ -n "$nf" ] && [ -n "$ini" ] && [ "$nf" -lt "$ini" ]
}

@test "creates a missing category" {
  run "$SC" "$FIX/p" Fixed "a bugfix"
  [ "$status" -eq 0 ]
  grep -q '^### Fixed$' "$FIX/p/CHANGELOG.md"
  grep -q '^- a bugfix$' "$FIX/p/CHANGELOG.md"
}

@test "does not touch released version sections" {
  "$SC" "$FIX/p" Added "x" >/dev/null
  grep -qF '## [0.1.0](x) (2026-01-01)' "$FIX/p/CHANGELOG.md"
  grep -q 'released thing' "$FIX/p/CHANGELOG.md"
}

@test "creating a category in an empty [Unreleased] leaves no trailing blank" {
  printf '# Changelog\n\n## [Unreleased]\n' >"$FIX/p/CHANGELOG.md"
  run "$SC" "$FIX/p" Added "first ever"
  [ "$status" -eq 0 ]
  [ "$(tail -1 "$FIX/p/CHANGELOG.md")" = "- first ever" ]
}

@test "rejects an invalid category" {
  run "$SC" "$FIX/p" Bogus "x"
  [ "$status" -ne 0 ]
  [[ "$output" == *"category must be one of"* ]]
}

@test "errors when there is no [Unreleased] section" {
  printf '# Changelog\n\n## [1.0.0]\n' >"$FIX/p/CHANGELOG.md"
  run "$SC" "$FIX/p" Added "x"
  [ "$status" -ne 0 ]
  [[ "$output" == *"[Unreleased]"* ]]
}

@test "handles bullet text with shell/awk special characters" {
  # The literal $ / backslash are intentional — we assert they survive verbatim
  # (the script passes text via the environment, not awk -v).
  # shellcheck disable=SC2016
  run "$SC" "$FIX/p" Changed 'use $VAR & \n literally, "quoted"'
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  grep -qF 'use $VAR & \n literally, "quoted"' "$FIX/p/CHANGELOG.md"
}
