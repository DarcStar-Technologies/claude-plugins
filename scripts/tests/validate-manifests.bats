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
  jq '.name = "wrong"' "$FIX/plugins/mismatch/.claude-plugin/plugin.json" >"$FIX/t" &&
    mv "$FIX/t" "$FIX/plugins/mismatch/.claude-plugin/plugin.json"
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

@test "templates (under templates/) need not be in the marketplace" {
  add_template default 0.1.0
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
    "$FIX/.claude-plugin/marketplace.json" >"$FIX/t" &&
    mv "$FIX/t" "$FIX/.claude-plugin/marketplace.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must not pin a 'version'"* ]]
}

@test "a template with a valid template.json (metadata + deps) passes" {
  add_template default 0.1.0
  jq '.dependencies = [{"kind":"cli","name":"jq","reason":"parses metadata"},
                       {"kind":"plugin","name":"edit-kit","version":">=0.1.0"}]' \
    "$FIX/templates/default/template.json" >"$FIX/t" && mv "$FIX/t" "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -eq 0 ]
}

@test "fails when a template is missing template.json" {
  add_template default 0.1.0
  rm "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing template.json"* ]]
}

@test "fails when template.json identity drifts from plugin.json (and names the field)" {
  add_template default 0.1.0
  jq '.description = "DRIFTED"' "$FIX/templates/default/template.json" >"$FIX/t" &&
    mv "$FIX/t" "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"[description] do not match plugin.json"* ]]
}

@test "drift check covers keywords too" {
  add_template default 0.1.0
  jq '.keywords = ["different"]' "$FIX/templates/default/template.json" >"$FIX/t" &&
    mv "$FIX/t" "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"[keywords] do not match plugin.json"* ]]
}

@test "fails specifically on the template.json name-vs-directory check" {
  add_template default 0.1.0
  # Only template.json.name is wrong; plugin.json.name stays == dir, so the sole error
  # is the template.json name-vs-directory check (not plugin.json's, and not drift).
  jq '.name = "wrong"' "$FIX/templates/default/template.json" >"$FIX/t" &&
    mv "$FIX/t" "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"template.json name 'wrong' does not match directory"* ]]
}

@test "fails when a template.json dependency has an invalid kind" {
  add_template default 0.1.0
  jq '.dependencies = [{"kind":"bogus","name":"x"}]' \
    "$FIX/templates/default/template.json" >"$FIX/t" && mv "$FIX/t" "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid 'kind'"* ]]
}

@test "fails when a template.json dependency is missing a name" {
  add_template default 0.1.0
  jq '.dependencies = [{"kind":"cli"}]' \
    "$FIX/templates/default/template.json" >"$FIX/t" && mv "$FIX/t" "$FIX/templates/default/template.json"
  run "$FIX/scripts/validate-manifests.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing/empty 'name'"* ]]
}
