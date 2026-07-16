#!/usr/bin/env bats

load helpers

setup() { setup_full_fixture; }
teardown() { teardown_fixture; }

# Advance the _template version inside the fixture.
bump_template() {
  jq --arg v "$1" '.version = $v' \
    "$FIX/plugins/_template/.claude-plugin/plugin.json" >"$FIX/t" &&
    mv "$FIX/t" "$FIX/plugins/_template/.claude-plugin/plugin.json"
}

tpl_field() { jq -r ".version | split(\".\")[$1] | tonumber" "$FIX/plugins/_template/.claude-plugin/plugin.json"; }
# Bump to the next major (guaranteed MAJOR drift from the current version).
bump_major() { bump_template "$(($(tpl_field 0) + 1)).0.0"; }
# Bump to a higher minor, same major (minor drift, never major).
bump_minor() { bump_template "$(tpl_field 0).$(($(tpl_field 1) + 1)).0"; }

@test "strict mode fails on unlisted major template drift" {
  fixture_scaffold acme-tool >/dev/null # scaffolded at 0.1.0
  bump_major                            # template -> major 1
  run "$FIX/scripts/scaffold-report.sh" --strict
  [ "$status" -ne 0 ]
  [[ "$output" == *"MAJOR-DRIFT"* ]]
}

@test "default (non-strict) mode never fails, even on major drift" {
  fixture_scaffold acme-tool >/dev/null
  bump_major
  run "$FIX/scripts/scaffold-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MAJOR-DRIFT"* ]]
}

@test "exception list lets a plugin lag a major version under --strict" {
  fixture_scaffold acme-tool >/dev/null
  bump_major
  printf '{ "exceptions": { "acme-tool": "pinned pending migration" } }\n' \
    >"$FIX/.scaffold-exceptions.json"
  run "$FIX/scripts/scaffold-report.sh" --strict
  [ "$status" -eq 0 ]
  [[ "$output" == *"MAJOR-DRIFT(allowed)"* ]]
}

@test "strict mode tolerates minor/patch drift" {
  fixture_scaffold acme-tool >/dev/null
  bump_minor
  run "$FIX/scripts/scaffold-report.sh" --strict
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" != *"MAJOR-DRIFT"* ]]
}

@test "strict mode passes when no plugin has drifted" {
  fixture_scaffold acme-tool >/dev/null
  run "$FIX/scripts/scaffold-report.sh" --strict
  [ "$status" -eq 0 ]
}

@test "invalid exceptions file is rejected" {
  printf 'not json\n' >"$FIX/.scaffold-exceptions.json"
  run "$FIX/scripts/scaffold-report.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid JSON"* ]]
}
