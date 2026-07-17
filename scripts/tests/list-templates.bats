#!/usr/bin/env bats
#
# Tests for scripts/list-templates.sh — template discovery.

load helpers

setup() { setup_full_fixture; }
teardown() { teardown_fixture; }

@test "lists every template under templates/ with version and description" {
  run "$FIX/scripts/list-templates.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"default"* ]]
  [[ "$output" == *"command-suite"* ]]
}

@test "does not list public plugins (under plugins/)" {
  add_plugin acme-tool 0.1.0
  run "$FIX/scripts/list-templates.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"acme-tool"* ]]
}

@test "--json emits a valid array of {name, version, description}" {
  run "$FIX/scripts/list-templates.sh" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r 'type' <<<"$output")" = "array" ]
  [ "$(jq -r 'all(.[]; has("name") and has("version") and has("description"))' <<<"$output")" = "true" ]
  # command-suite is listed; assert a valid semver version rather than a pinned value
  # (the real templates are read, so a pinned version goes stale every time it releases).
  [ "$(jq -r 'any(.[]; .name == "command-suite")' <<<"$output")" = "true" ]
  [ "$(jq -r 'all(.[]; .version | test("^[0-9]+\\.[0-9]+\\.[0-9]+"))' <<<"$output")" = "true" ]
}
