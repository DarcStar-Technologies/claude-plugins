#!/usr/bin/env bats
#
# Tests for edit-kit/scripts/check-structure.sh — the domain-agnostic structural
# validation half of what was plugin-editor's check-template.sh (no template-drift).
# Each test builds a throwaway plugin-shaped target dir so the real repo is untouched.

load helpers

setup() {
  CS="$(repo_root_dir)/plugins/edit-kit/scripts/check-structure.sh"
  FIX="$(mktemp -d)"
  T="$FIX/mytool"
  mkdir -p "$T/.claude-plugin"
  printf '{"name":"mytool","version":"0.1.0","description":"A tool."}\n' >"$T/.claude-plugin/plugin.json"
  printf '# mytool\n' >"$T/README.md"
  printf '# mytool — Context\n' >"$T/CONTEXT.md"
  printf '# Changelog\n\n## [Unreleased]\n\n### Added\n\n- init\n' >"$T/CHANGELOG.md"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "a well-formed target passes" {
  run "$CS" "$T"
  [ "$status" -eq 0 ]
  [[ "$output" == *"structure OK (target)"* ]]
}

@test "fails on invalid or missing plugin.json" {
  printf 'not json\n' >"$T/.claude-plugin/plugin.json"
  run "$CS" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid or missing plugin.json"* ]]
  [[ "$output" == *"STRUCTURE CHECK FAILED"* ]]
}

@test "fails on a non-semver version" {
  printf '{"name":"mytool","version":"1.2","description":"A tool."}\n' >"$T/.claude-plugin/plugin.json"
  run "$CS" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is not valid semver"* ]]
}

@test "fails on a missing required doc" {
  rm "$T/CONTEXT.md"
  run "$CS" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing CONTEXT.md"* ]]
}

@test "fails when CHANGELOG.md lacks a title or version section" {
  printf 'just some text\n' >"$T/CHANGELOG.md"
  run "$CS" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CHANGELOG.md"* ]]
}

@test "a name/dir mismatch is a note, not a failure" {
  printf '{"name":"other","version":"0.1.0","description":"A tool."}\n' >"$T/.claude-plugin/plugin.json"
  run "$CS" "$T"
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not match directory"* ]]
  [[ "$output" == *"structure OK"* ]]
}

@test "shellchecks the target's scripts and fails on a lint error" {
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
  mkdir -p "$T/scripts"
  # SC2168: 'local' outside a function — an error-level finding, config-immune.
  printf '#!/usr/bin/env bash\nlocal x=1\n' >"$T/scripts/bad.sh"
  run "$CS" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"STRUCTURE CHECK FAILED"* ]]
}

@test "errors on usage with no target" {
  run "$CS"
  [ "$status" -ne 0 ]
}
