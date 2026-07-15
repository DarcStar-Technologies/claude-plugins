#!/usr/bin/env bats

load helpers

setup() { setup_fixture; }
teardown() { teardown_fixture; }

@test "passes for a valid, registered plugin" {
  add_plugin good 1.0.0
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -eq 0 ]
}

@test "passes with no plugins at all" {
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -eq 0 ]
}

@test "fails when a version is not semver" {
  add_plugin bad 1.0
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid semver"* ]]
}

@test "fails when the plugin name does not match its directory" {
  add_plugin mismatch 1.0.0
  jq '.name = "wrong"' "$FIX/plugins/mismatch/.claude-plugin/plugin.json" >"$FIX/t" \
    && mv "$FIX/t" "$FIX/plugins/mismatch/.claude-plugin/plugin.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not match directory"* ]]
}

@test "fails when a public plugin is missing from the marketplace" {
  add_plugin lonely 1.0.0
  echo '{"name":"test","plugins":[]}' >"$FIX/.claude-plugin/marketplace.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not listed in marketplace"* ]]
}

@test "internal (_-prefixed) plugins need not be in the marketplace" {
  add_plugin _template 0.1.0
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -eq 0 ]
}

@test "fails when a public plugin lacks scaffold provenance" {
  add_plugin unscaffolded 1.0.0 --no-scaffold
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"scaffold.json"* ]]
}

@test "marketplace entries must not pin a version" {
  add_plugin versioned 1.0.0
  jq '(.plugins[] | select(.name == "versioned")) += {version: "1.0.0"}' \
    "$FIX/.claude-plugin/marketplace.json" >"$FIX/t" \
    && mv "$FIX/t" "$FIX/.claude-plugin/marketplace.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not pin a 'version'"* ]]
}
