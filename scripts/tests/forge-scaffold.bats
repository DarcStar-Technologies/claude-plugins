#!/usr/bin/env bats
#
# Tests for the plugin-forge portable scaffolder. All cases use local template
# sources (a local ./default and a local git repo) so the suite never touches
# the network. The remote --template-version / default paths are exercised
# manually and documented in the plugin's CONTEXT.md.

load helpers

setup() {
  WORK="$(mktemp -d)"
  SCAFFOLDER="$(repo_root_dir)/plugins/plugin-forge/scripts/forge-scaffold.sh"
  # A local template in the work dir → the "local ./default" resolution.
  cp -R "$(repo_root_dir)/templates/default" "$WORK/default"
}
teardown() { [[ -n "${WORK:-}" ]] && rm -rf "$WORK"; }

# Make a local template dir <name> in $WORK with the given template.json dependencies
# JSON. Echoes nothing; the template resolves via forge's local `./<name>` path.
make_dep_template() {
  local name="$1" deps_json="$2"
  local d="$WORK/$name" # separate decl: $d must see the $name assigned above
  mkdir -p "$d/.claude-plugin" "$d/scripts"
  printf '{"name":"%s","version":"0.1.0","description":"d","license":"MIT","keywords":["x"]}\n' \
    "$name" >"$d/.claude-plugin/plugin.json"
  jq -n --arg n "$name" --argjson deps "$deps_json" \
    '{name:$n,description:"d",license:"MIT",keywords:["x"],dependencies:$deps}' >"$d/template.json"
  printf '#!/usr/bin/env bash\necho hi\n' >"$d/scripts/x.sh"
}

@test "propagates a template's plugin-kind dependency into the scaffolded plugin.json" {
  make_dep_template deptmpl '[{"kind":"plugin","name":"edit-kit","version":">=0.1.0"}]'
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'X.' --template deptmpl"
  [ "$status" -eq 0 ]
  run jq -c '.dependencies' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = '[{"name":"edit-kit","version":">=0.1.0"}]' ]
}

@test "a bare (no-version) plugin dep propagates as a bare string" {
  make_dep_template deptmpl '[{"kind":"plugin","name":"semver"}]'
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'X.' --template deptmpl"
  [ "$status" -eq 0 ]
  run jq -c '.dependencies' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = '["semver"]' ]
}

@test "documents cli/library/mcp deps in the scaffolded CONTEXT.md, not plugin.json" {
  make_dep_template deptmpl '[{"kind":"cli","name":"jq","reason":"parses metadata"},{"kind":"mcp","name":"github"}]'
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'X.' --template deptmpl"
  [ "$status" -eq 0 ]
  # cli/mcp deps are NOT plugin-kind, so plugin.json carries no dependencies field
  run jq 'has("dependencies")' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = "false" ]
  grep -q '## Dependencies' "$WORK/mytool/CONTEXT.md"
  grep -q -- '- \*\*jq\*\* (cli) — parses metadata' "$WORK/mytool/CONTEXT.md"
  grep -q -- '- \*\*github\*\* (mcp)' "$WORK/mytool/CONTEXT.md"
}

@test "a template with no template.json propagates nothing (no deps, no Dependencies section)" {
  # default now ships a template.json; remove it so this exercises the missing-file branch.
  rm -f "$WORK/default/template.json"
  run bash -c "cd '$WORK' && '$SCAFFOLDER' plain --description 'X.' --template default"
  [ "$status" -eq 0 ]
  run jq 'has("dependencies")' "$WORK/plain/.claude-plugin/plugin.json"
  [ "$output" = "false" ]
  run grep -c '## Dependencies' "$WORK/plain/CONTEXT.md"
  [ "$output" = "0" ]
}

@test "a dependency reason containing '&' is preserved verbatim (no bash patsub corruption)" {
  make_dep_template deptmpl '[{"kind":"cli","name":"make","reason":"build & release"}]'
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'X.' --template deptmpl"
  [ "$status" -eq 0 ]
  grep -q -- '- \*\*make\*\* (cli) — build & release' "$WORK/mytool/CONTEXT.md"
  run grep -q '@@DEPS@@' "$WORK/mytool/CONTEXT.md"
  [ "$status" -ne 0 ] # no leftover token
}

@test "a malformed template.json dependency (missing name/kind) is dropped, not propagated" {
  make_dep_template deptmpl '[{"kind":"plugin","version":">=1.0.0"},{"name":"orphan"},{"kind":"cli"}]'
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'X.' --template deptmpl"
  [ "$status" -eq 0 ]
  # no null-valued garbage in either output
  run jq 'has("dependencies")' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = "false" ]
  run grep -q 'null' "$WORK/mytool/CONTEXT.md"
  [ "$status" -ne 0 ] # no null-valued garbage
}

# Make a throwaway git repo containing templates/default; echoes its path.
make_template_repo() {
  local src="$WORK/src"
  mkdir -p "$src/templates"
  cp -R "$(repo_root_dir)/templates/default" "$src/templates/default"
  git -C "$src" init -q
  git -C "$src" add -A
  git -C "$src" -c user.email=t@t -c user.name=t commit -qm init
  printf '%s' "$src"
}

@test "portable scaffold from a local ./default produces a valid plugin" {
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'Does things.' --author 'A'"
  [ "$status" -eq 0 ]
  [ -f "$WORK/mytool/.claude-plugin/plugin.json" ]
  [ -f "$WORK/mytool/CONTEXT.md" ]
  [ -f "$WORK/mytool/README.md" ]
  [ -f "$WORK/mytool/CHANGELOG.md" ]
  run jq -r '.name' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = "mytool" ]
  run jq -r '.version' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = "0.1.0" ]
  run jq 'has("homepage")' "$WORK/mytool/.claude-plugin/plugin.json"
  [ "$output" = "false" ]
}

@test "substitutes {{NAME}} placeholders but preserves binary assets verbatim" {
  # A binary asset in a component dir must survive the copy byte-for-byte: the
  # scaffolder only rewrites text files that contain a placeholder.
  printf '\x00\x01\x02\xff\xfe payload \x00 end' \
    >"$WORK/default/skills/example-skill/logo.bin"
  cp "$WORK/default/skills/example-skill/logo.bin" "$WORK/orig.bin"

  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool --description 'Does things.'"
  [ "$status" -eq 0 ]

  # {{NAME}} in a component is replaced with the new plugin's name...
  grep -q 'from the mytool plugin' "$WORK/mytool/scripts/example.sh"
  # ...with no placeholder left behind (run+status, since `!` doesn't fail a Bats
  # test and `run !` needs Bats >= 1.5.0).
  run grep -q '{{NAME}}' "$WORK/mytool/scripts/example.sh"
  [ "$status" -ne 0 ]
  # ...and the binary asset is byte-for-byte identical (not corrupted by cat).
  cmp -s "$WORK/orig.bin" "$WORK/mytool/skills/example-skill/logo.bin"
}

@test "records portable provenance with the resolved source" {
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool"
  [ "$status" -eq 0 ]
  run jq -r '.mode' "$WORK/mytool/.claude-plugin/scaffold.json"
  [ "$output" = "portable" ]
  run jq -r '.source' "$WORK/mytool/.claude-plugin/scaffold.json"
  [ "$output" = "local:./default" ]
}

@test "--template-version resolves a NEW double-hyphen tag from the default repo" {
  local src
  src="$(make_template_repo)"
  git -C "$src" tag default--v0.5.0
  run env FORGE_DEFAULT_REPO="$src" bash "$SCAFFOLDER" vtool --template-version 0.5.0 --out "$WORK"
  [ "$status" -eq 0 ]
  [ -f "$WORK/vtool/.claude-plugin/plugin.json" ]
  run jq -r '.source' "$WORK/vtool/.claude-plugin/scaffold.json"
  [ "$output" = "tag:default--v0.5.0" ]
}

@test "--template-version falls back to a legacy single-hyphen tag" {
  local src
  src="$(make_template_repo)"
  git -C "$src" tag default-v0.4.0 # only the legacy scheme exists for this version
  run env FORGE_DEFAULT_REPO="$src" bash "$SCAFFOLDER" ltool --template-version 0.4.0 --out "$WORK"
  [ "$status" -eq 0 ]
  run jq -r '.source' "$WORK/ltool/.claude-plugin/scaffold.json"
  [ "$output" = "tag:default-v0.4.0" ]
}

@test "--template-version dies clearly when neither tag scheme exists" {
  local src
  src="$(make_template_repo)" # no tag at all for 9.9.9
  run env FORGE_DEFAULT_REPO="$src" bash "$SCAFFOLDER" xtool --template-version 9.9.9 --out "$WORK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"9.9.9"* ]]
}

@test "does not inherit the template's release history (clean [Unreleased])" {
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool"
  [ "$status" -eq 0 ]
  run grep -c '^## ' "$WORK/mytool/CHANGELOG.md"
  [ "$output" = "1" ]
  grep -q '## \[Unreleased\]' "$WORK/mytool/CHANGELOG.md"
}

@test "portable mode registers nothing (no marketplace/release files)" {
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool"
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/.claude-plugin/marketplace.json" ]
  [ ! -e "$WORK/release-please-config.json" ]
  [ ! -e "$WORK/.release-please-manifest.json" ]
}

@test "resolves a template from a local git repo via --template-repo" {
  local src
  src="$(make_template_repo)"
  run bash "$SCAFFOLDER" repotool --template-repo "$src" --out "$WORK"
  [ "$status" -eq 0 ]
  [ -f "$WORK/repotool/.claude-plugin/plugin.json" ]
  run jq -r '.source' "$WORK/repotool/.claude-plugin/scaffold.json"
  [[ "$output" == repo:* ]]
}

@test "--template-repo takes precedence over a local ./default" {
  local src
  src="$(make_template_repo)"
  run bash -c "cd '$WORK' && '$SCAFFOLDER' prectool --template-repo '$src'"
  [ "$status" -eq 0 ]
  run jq -r '.source' "$WORK/prectool/.claude-plugin/scaffold.json"
  [[ "$output" == repo:* ]]
}

@test "a local relative path is used as-is, not treated as owner/repo (finding 1)" {
  local src="$WORK/myorg/myrepo"
  mkdir -p "$src/templates"
  cp -R "$(repo_root_dir)/templates/default" "$src/templates/default"
  git -C "$src" init -q
  git -C "$src" add -A
  git -C "$src" -c user.email=t@t -c user.name=t commit -qm init
  run bash -c "cd '$WORK' && '$SCAFFOLDER' f1 --template-repo myorg/myrepo"
  [ "$status" -eq 0 ]
  run jq -r '.source' "$WORK/f1/.claude-plugin/scaffold.json"
  [ "$output" = "repo:myorg/myrepo" ]
}

@test "an @-bearing URL is not mangled by ref parsing (finding 2)" {
  # ssh-style URL keeps its @; GIT_SSH_COMMAND=false makes the fetch fail fast
  # instead of hanging on a TCP connect. The error must show the URL intact.
  run env GIT_SSH_COMMAND=false bash "$SCAFFOLDER" f2 --template-repo "git@example.com:owner/repo.git"
  [ "$status" -ne 0 ]
  [[ "$output" == *"git@example.com:owner/repo.git"* ]]
}

@test "rejects an underscore-prefixed name" {
  run bash "$SCAFFOLDER" _bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"lowercase alphanumeric"* ]]
}

@test "refuses to overwrite an existing destination" {
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool"
  [ "$status" -eq 0 ]
  run bash -c "cd '$WORK' && '$SCAFFOLDER' mytool"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}
