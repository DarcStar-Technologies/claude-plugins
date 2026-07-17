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
  # Seed an existing plugin package so component-collision is exercisable.
  printf '{"packages":{"plugins/semver":{"component":"semver"}}}\n' >"$FIX/release-please-config.json"
  printf '{"plugins/semver":"1.0.0"}\n' >"$FIX/.release-please-manifest.json"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

# make a source plugin under the fixture: <name> <description> [<comp-dir> <file> <contents>]
mkplugin() {
  local pn="$1" pd="$2"
  mkdir -p "$FIX/plugins/$pn/.claude-plugin"
  jq -n --arg n "$pn" --arg d "$pd" '{name:$n,version:"1.0.0",description:$d}' \
    >"$FIX/plugins/$pn/.claude-plugin/plugin.json"
}

# --- default mode --------------------------------------------------------

@test "default mode creates a valid template and registers it (not in marketplace)" {
  run "$TF" my-arch --description 'An X archetype.' --components "commands scripts" --register "$FIX"
  [ "$status" -eq 0 ]
  [ -f "$FIX/templates/my-arch/.claude-plugin/plugin.json" ]
  [ -d "$FIX/templates/my-arch/commands" ]
  [ -d "$FIX/templates/my-arch/scripts" ]
  [ ! -d "$FIX/templates/my-arch/agents" ]
  run jq -r '.name + " " + .version' "$FIX/templates/my-arch/.claude-plugin/plugin.json"
  [ "$output" = "my-arch 0.1.0" ]
  [ ! -f "$FIX/templates/my-arch/.claude-plugin/scaffold.json" ]
  run jq -r '.plugins | length' "$FIX/.claude-plugin/marketplace.json"
  [ "$output" = "0" ]
}

@test "default mode writes a template.json consistent with plugin.json (empty deps, no version)" {
  run "$TF" my-arch --description 'An X archetype.' --author 'Me' --register "$FIX"
  [ "$status" -eq 0 ]
  [ -f "$FIX/templates/my-arch/template.json" ]
  # required shape: name == dir, dependencies == [], and NO version (release-please owns it)
  run jq -e '.name == "my-arch" and .dependencies == [] and (has("version") | not)' \
    "$FIX/templates/my-arch/template.json"
  [ "$status" -eq 0 ]
  # identity fields match plugin.json — exactly the no-drift invariant validate-manifests enforces
  local t="$FIX/templates/my-arch/template.json" p="$FIX/templates/my-arch/.claude-plugin/plugin.json"
  run jq -rn --slurpfile a "$t" --slurpfile b "$p" \
    '["name","description","author","license","keywords"] | all(.[]; $a[0][.] == $b[0][.])'
  [ "$output" = "true" ]
}

@test "registers a release-please package with the template-specific shape" {
  run "$TF" my-arch --description 'An X archetype.' --register "$FIX"
  [ "$status" -eq 0 ]
  run jq -r '.packages["templates/my-arch"]["release-type"]' "$FIX/release-please-config.json"
  [ "$output" = "simple" ]
  run jq -c '.packages["templates/my-arch"]["exclude-paths"]' "$FIX/release-please-config.json"
  [ "$output" = '["templates/my-arch/README.md","templates/my-arch/CONTEXT.md","templates/my-arch/CHANGELOG.md"]' ]
  run jq -r '.packages["templates/my-arch"]["extra-files"][0].jsonpath' "$FIX/release-please-config.json"
  [ "$output" = '$.version' ]
  run jq -r '.["templates/my-arch"]' "$FIX/.release-please-manifest.json"
  [ "$output" = "0.0.0" ]
}

@test "the template's own docs keep literal {{NAME}}/{{DESC}} guidance (title uses the real name)" {
  run "$TF" my-arch --description 'An X archetype.' --register "$FIX"
  [ "$status" -eq 0 ]
  run head -n1 "$FIX/templates/my-arch/README.md"
  [ "$output" = "# my-arch" ]
  # The description renders into the docs (identity via @@DESC@@)...
  run grep -F 'An X archetype.' "$FIX/templates/my-arch/CONTEXT.md"
  [ "$status" -eq 0 ]
  # ...but the literal {{NAME}}/{{DESC}} GUIDANCE tokens must survive untouched.
  run grep -F '{{NAME}}' "$FIX/templates/my-arch/README.md"
  [ "$status" -eq 0 ]
  run grep -F '{{DESC}}' "$FIX/templates/my-arch/CONTEXT.md"
  [ "$status" -eq 0 ]
}

# --- from-plugin mode ----------------------------------------------------

@test "from-plugin copies components (commands+agents) and reverses identity" {
  mkplugin foo-bar "Does the foo-bar thing."
  mkdir -p "$FIX/plugins/foo-bar/commands" "$FIX/plugins/foo-bar/agents"
  printf '# foo-bar\n\nDoes the foo-bar thing.\n\nInvoke foo-bar to run it.\n' \
    >"$FIX/plugins/foo-bar/commands/run.md"
  printf '# foo-bar helper\n\nAssists foo-bar.\n' >"$FIX/plugins/foo-bar/agents/help.md"
  run "$TF" foo-arch --description 'Generic.' --from-plugin plugins/foo-bar --register "$FIX"
  [ "$status" -eq 0 ]
  run cat "$FIX/templates/foo-arch/commands/run.md"
  [[ "$output" == *"{{DESC}}"* ]]
  [[ "$output" == *"{{NAME}}"* ]]
  [[ "$output" != *"foo-bar"* ]]
  # agents/ dir is copied and reversed too.
  [ -f "$FIX/templates/foo-arch/agents/help.md" ]
  run cat "$FIX/templates/foo-arch/agents/help.md"
  [[ "$output" != *"foo-bar"* ]]
}

@test "from-plugin preserves a single trailing newline (markdownlint MD047)" {
  mkplugin foo-bar "Does the foo-bar thing."
  mkdir -p "$FIX/plugins/foo-bar/commands"
  printf '# foo-bar\n\nUse foo-bar here.\n' >"$FIX/plugins/foo-bar/commands/run.md"
  run "$TF" foo-arch --from-plugin plugins/foo-bar --register "$FIX"
  [ "$status" -eq 0 ]
  # Last byte must be a newline, and there must be exactly one.
  run tail -c1 "$FIX/templates/foo-arch/commands/run.md"
  [ "$output" = "" ] # tail -c1 of a file ending in \n yields empty $output
  [ "$(tail -c2 "$FIX/templates/foo-arch/commands/run.md" | od -An -tx1 | tr -d ' ')" != "0a0a" ]
}

@test "from-plugin matches a regex-metacharacter description literally (grep -F)" {
  mkplugin cfgtool "Manage [config] files."
  mkdir -p "$FIX/plugins/cfgtool/skills"
  # A file containing ONLY the description (not the name) — a regex grep would miss it.
  printf 'Manage [config] files.\n' >"$FIX/plugins/cfgtool/skills/note.md"
  run "$TF" cfg-arch --from-plugin plugins/cfgtool --register "$FIX"
  [ "$status" -eq 0 ]
  run cat "$FIX/templates/cfg-arch/skills/note.md"
  [[ "$output" == *"{{DESC}}"* ]]
  [[ "$output" != *"[config]"* ]]
}

@test "from-plugin reverses the name only on word boundaries (no substring corruption)" {
  mkplugin go "Go runner."
  mkdir -p "$FIX/plugins/go/commands"
  printf '# go\n\nPick a category, then run go now.\n' >"$FIX/plugins/go/commands/run.md"
  run "$TF" go-arch --from-plugin plugins/go --register "$FIX"
  [ "$status" -eq 0 ]
  run cat "$FIX/templates/go-arch/commands/run.md"
  [[ "$output" == *"category"* ]]         # 'go' inside 'category' is NOT rewritten
  [[ "$output" == *"run {{NAME}} now"* ]] # standalone 'go' IS rewritten
  [[ "$output" != *"cate{{NAME}}ry"* ]]
}

@test "rejects a --from-plugin whose plugin name is non-standard" {
  mkdir -p "$FIX/plugins/weird/.claude-plugin"
  printf '{"name":"Weird.Name","version":"1.0.0","description":"x"}\n' \
    >"$FIX/plugins/weird/.claude-plugin/plugin.json"
  run "$TF" w-arch --from-plugin plugins/weird --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a standard plugin name"* ]]
  [ ! -e "$FIX/templates/w-arch" ]
}

# --- idempotency, fail-fast & validation --------------------------------

@test "fails if the destination already exists" {
  "$TF" my-arch --register "$FIX" >/dev/null
  run "$TF" my-arch --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"destination already exists"* ]]
}

@test "fails BEFORE writing if a templates/<name> package already exists" {
  tmp="$(mktemp)"
  jq '.packages["templates/dupe"] = {"component":"dupe"}' \
    "$FIX/release-please-config.json" >"$tmp"
  mv "$tmp" "$FIX/release-please-config.json"
  run "$TF" dupe --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already has a templates/dupe package"* ]]
  [ ! -e "$FIX/templates/dupe" ]
}

@test "rejects a name that collides with an existing plugin's release component" {
  run "$TF" semver --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"collides with an existing plugin"* ]]
  [ ! -e "$FIX/templates/semver" ]
}

@test "no half-create: missing release config dies before writing the dest" {
  rm -f "$FIX/release-please-config.json"
  run "$TF" my-arch --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"release-please-config.json not found"* ]]
  [ ! -e "$FIX/templates/my-arch" ]
}

@test "no half-create: missing manifest dies before writing the dest" {
  rm -f "$FIX/.release-please-manifest.json"
  run "$TF" my-arch --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"manifest.json not found"* ]]
  [ ! -e "$FIX/templates/my-arch" ]
}

@test "no half-create: an unknown component type dies before writing the dest" {
  run "$TF" my-arch --components "commands widgets" --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown component type"* ]]
  [ ! -e "$FIX/templates/my-arch" ]
}

@test "rejects an invalid template name" {
  run "$TF" Bad_Name --register "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"lowercase alphanumeric"* ]]
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
  run jq -r '.packages | keys | length' "$FIX/release-please-config.json"
  [ "$output" = "1" ] # unchanged: only the seeded plugins/semver
}
