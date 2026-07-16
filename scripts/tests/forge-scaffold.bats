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
