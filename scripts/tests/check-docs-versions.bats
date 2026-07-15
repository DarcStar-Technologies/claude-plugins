#!/usr/bin/env bats

load helpers

setup() { setup_fixture; }
teardown() { teardown_fixture; }

@test "check-plugin-docs passes when all docs exist" {
  add_plugin documented 1.0.0
  run "$FIX/scripts/check-plugin-docs.sh"
  [ "$status" -eq 0 ]
}

@test "check-plugin-docs fails when CONTEXT.md is missing" {
  add_plugin bare 1.0.0 --no-context
  run "$FIX/scripts/check-plugin-docs.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing CONTEXT.md"* ]]
}

@test "check-versions passes for a Keep-a-Changelog file" {
  add_plugin versioned 2.3.4
  run "$FIX/scripts/check-versions.sh"
  [ "$status" -eq 0 ]
}

@test "check-versions fails when CHANGELOG.md is missing" {
  add_plugin nolog 1.0.0 --no-changelog
  run "$FIX/scripts/check-versions.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing CHANGELOG.md"* ]]
}

@test "check-versions fails when the changelog lacks a title" {
  add_plugin untitled 1.0.0
  printf '## [Unreleased]\n' >"$FIX/plugins/untitled/CHANGELOG.md"
  run "$FIX/scripts/check-versions.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing '# Changelog' title"* ]]
}
