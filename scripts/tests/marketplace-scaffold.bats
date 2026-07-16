#!/usr/bin/env bats
#
# Marketplace-mode scaffolding: forge-scaffold.sh --register <root> scaffolds into
# the repo and registers the plugin in the catalog + release automation.

load helpers

setup() { setup_full_fixture; }
teardown() { teardown_fixture; }

@test "marketplace scaffold produces a valid, registered plugin" {
  run fixture_scaffold acme-tool --description "Acme things"
  [ "$status" -eq 0 ]
  [ -f "$FIX/plugins/acme-tool/.claude-plugin/plugin.json" ]
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -eq 0 ]
}

@test "records scaffold provenance (marketplace mode)" {
  fixture_scaffold acme-tool >/dev/null
  local prov="$FIX/plugins/acme-tool/.claude-plugin/scaffold.json"
  [ -f "$prov" ]
  run jq -r '.template' "$prov"
  [ "$output" = "_template" ]
  run jq -r '.templateVersion' "$prov"
  [ "$output" = "$(jq -r '.version' "$FIX/plugins/_template/.claude-plugin/plugin.json")" ]
  run jq -r '.mode' "$prov"
  [ "$output" = "marketplace" ]
}

@test "registers in the catalog without a version, and in release config" {
  fixture_scaffold acme-tool >/dev/null
  run jq -r '.plugins[] | select(.name == "acme-tool") | has("version")' "$FIX/.claude-plugin/marketplace.json"
  [ "$output" = "false" ]
  run jq -r '.packages | has("plugins/acme-tool")' "$FIX/release-please-config.json"
  [ "$output" = "true" ]
  run jq -r '."plugins/acme-tool"' "$FIX/.release-please-manifest.json"
  [ "$output" = "0.0.0" ]
}

@test "rejects an unknown template" {
  run fixture_scaffold acme-tool --template _nope
  [ "$status" -ne 0 ]
}

@test "refuses to overwrite an existing plugin" {
  fixture_scaffold acme-tool >/dev/null
  run fixture_scaffold acme-tool
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}
