#!/usr/bin/env bats
#
# Tests for plugins/template-forge/scripts/template-forge-scaffold.sh — the
# deterministic scaffolder that creates a new reference template under templates/.
# Each test builds a throwaway marketplace fixture so the real repo is untouched.
# The defining property: a template is registered for release management but NEVER
# added to marketplace.json (that omission is what keeps it internal).

load helpers

setup() {
  TF="$(repo_root_dir)/plugins/template-forge/scripts/template-forge-scaffold.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/templates" "$FIX/plugins"
  printf '{"name":"test","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  printf '{"packages":{}}\n' >"$FIX/release-please-config.json"
  printf '{}\n' >"$FIX/.release-please-manifest.json"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

# --- default mode --------------------------------------------------------

@test "default mode creates a valid template and registers it (not in marketplace)" {
  run "$TF" my-arch --description 'An X archetype.' --components "commands scripts" --register "$FIX"
  [ "$status" -eq 0 ]
  [ -f "$FIX/templates/my-arch/.claude-plugin/plugin.json" ]
  [ -f "$FIX/templates/my-arch/README.md" ]
  [ -f "$FIX/templates/my-arch/CONTEXT.md" ]
  [ -f "$FIX/templates/my-arch/CHANGELOG.md" ]
  [ -d "$FIX/templates/my-arch/commands" ]
  [ -d "$FIX/templates/my-arch/scripts" ]
  [ ! -d "$FIX/templates/my-arch/agents" ]
  # plugin.json: name matches dir, version 0.1.0.
  run jq -r '.name + " " + .version' "$FIX/templates/my-arch/.claude-plugin/plugin.json"
  [ "$output" = "my-arch 0.1.0" ]
  # NO scaffold.json — a template is the source of scaffolding, not scaffolded.
  [ ! -f "$FIX/templates/my-arch/.claude-plugin/scaffold.json" ]
  # marketplace.json untouched.
  run jq -r '.plugins | length' "$FIX/.claude-plugin/marketplace.json"
  [ "$output" = "0" ]
}

@test "registers a release-please package with the template-specific shape" {
  run "$TF" my-arch --description 'An X archetype.' --register "$FIX"
  [ "$status" -eq 0 ]
  run jq -r '.packages["templates/my-arch"]["release-type"]' "$FIX/release-please-config.json"
  [ "$output" = "simple" ]
  run jq -r '.packages["templates/my-arch"].component' "$FIX/release-please-config.json"
  [ "$output" = "my-arch" ]
  run jq -c '.packages["templates/my-arch"]["exclude-paths"]' "$FIX/release-please-config.json"
  [ "$output" = '["templates/my-arch/README.md","templates/my-arch/CONTEXT.md","templates/my-arch/CHANGELOG.md"]' ]
  run jq -r '.packages["templates/my-arch"]["extra-files"][0].jsonpath' "$FIX/release-please-config.json"
  [ "$output" = '$.version' ]
  # Manifest seeded at 0.0.0.
  run jq -r '.["templates/my-arch"]' "$FIX/.release-please-manifest.json"
  [ "$output" = "0.0.0" ]
}

# --- from-plugin mode ----------------------------------------------------

@test "from-plugin copies components and reverses identity to placeholders" {
  mkdir -p "$FIX/plugins/foo-bar/.claude-plugin" "$FIX/plugins/foo-bar/commands"
  printf '{"name":"foo-bar","version":"1.0.0","description":"Does the foo-bar thing."}\n' \
    >"$FIX/plugins/foo-bar/.claude-plugin/plugin.json"
  printf '# foo-bar\n\nDoes the foo-bar thing.\n\nInvoke foo-bar to run it.\n' \
    >"$FIX/plugins/foo-bar/commands/run.md"
  run "$TF" foo-arch --description 'Generic.' --from-plugin plugins/foo-bar --register "$FIX"
  [ "$status" -eq 0 ]
  [ -f "$FIX/templates/foo-arch/commands/run.md" ]
  run cat "$FIX/templates/foo-arch/commands/run.md"
  # Description reversed first (name occurs within it), then the name.
  [[ "$output" == *"{{DESC}}"* ]]
  [[ "$output" == *"{{NAME}}"* ]]
  [[ "$output" != *"foo-bar"* ]]
}

# --- idempotency & validation -------------------------------------------

@test "fails if the destination already exists" {
  "$TF" my-arch --register "$FIX" >/dev/null
  run "$TF" my-arch --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"destination already exists"* ]]
}

@test "fails BEFORE writing if the release package is already registered" {
  # Pre-register the package but leave no dir, to prove the pre-check fires first.
  tmp="$(mktemp)"
  jq '.packages["templates/dupe"] = {}' "$FIX/release-please-config.json" >"$tmp"
  mv "$tmp" "$FIX/release-please-config.json"
  run "$TF" dupe --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already has a templates/dupe package"* ]]
  [ ! -d "$FIX/templates/dupe" ]
}

@test "rejects an invalid template name" {
  run "$TF" Bad_Name --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lowercase alphanumeric"* ]]
}

@test "rejects an unknown component type" {
  run "$TF" my-arch --components "commands widgets" --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown component type"* ]]
}

@test "rejects a register root that is not a marketplace" {
  local notmp
  notmp="$(mktemp -d)"
  run "$TF" my-arch --register "$notmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a marketplace"* ]]
  rm -rf "$notmp"
}

@test "without --register, creates locally and touches no registration files" {
  run "$TF" solo --description 'Local only.' --out "$FIX/loose"
  [ "$status" -eq 0 ]
  [ -f "$FIX/loose/solo/.claude-plugin/plugin.json" ]
  # Registration files remain empty/untouched.
  run jq -r '.packages | length' "$FIX/release-please-config.json"
  [ "$output" = "0" ]
}
