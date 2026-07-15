#!/usr/bin/env bats

load helpers

setup() { setup_full_fixture; }
teardown() { teardown_fixture; }

@test "new-plugin.sh scaffolds a valid, registered plugin" {
  run "$FIX/scripts/new-plugin.sh" acme-tool --description "Acme things"
  [ "$status" -eq 0 ]
  [ -f "$FIX/plugins/acme-tool/.claude-plugin/plugin.json" ]
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -eq 0 ]
}

@test "new-plugin.sh records scaffold provenance" {
  "$FIX/scripts/new-plugin.sh" acme-tool >/dev/null
  prov="$FIX/plugins/acme-tool/.claude-plugin/scaffold.json"
  [ -f "$prov" ]
  run jq -r '.template' "$prov"
  [ "$output" = "_template" ]
  run jq -r '.templateVersion' "$prov"
  [ "$output" = "0.1.0" ]
}

@test "scaffold-report lists the new plugin without drift" {
  "$FIX/scripts/new-plugin.sh" acme-tool >/dev/null
  run "$FIX/scripts/scaffold-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"acme-tool"* ]]
  [[ "$output" == *"_template"* ]]
  [[ "$output" != *"DRIFT"* ]]
}

@test "scaffold-report flags drift when the template advances" {
  "$FIX/scripts/new-plugin.sh" acme-tool >/dev/null
  # Bump the template version past what the plugin recorded (0.1.0).
  jq '.version = "0.2.0"' "$FIX/plugins/_template/.claude-plugin/plugin.json" >"$FIX/t" \
    && mv "$FIX/t" "$FIX/plugins/_template/.claude-plugin/plugin.json"
  run "$FIX/scripts/scaffold-report.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRIFT"* ]]
}

@test "new-plugin.sh rejects an unknown template" {
  run "$FIX/scripts/new-plugin.sh" acme-tool --template _nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown template"* ]]
}
