#!/usr/bin/env bats
#
# Tests for edit-kit/scripts/sync-version.sh.

load helpers

setup() {
  SV="$(repo_root_dir)/plugins/edit-kit/scripts/sync-version.sh"
  SEMVER_BIN="$(repo_root_dir)/plugins/semver/scripts/semver.sh"
  export SEMVER_BIN
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/plugins/p/.claude-plugin"
  printf '{"name":"p","version":"1.2.3","description":"t"}\n' \
    >"$FIX/plugins/p/.claude-plugin/plugin.json"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

ver() { jq -r '.version' "$FIX/plugins/p/.claude-plugin/plugin.json"; }

@test "release-please-managed plugin is NOT hand-bumped" {
  printf '{"packages":{"plugins/p":{"release-type":"simple"}}}\n' \
    >"$FIX/release-please-config.json"
  run "$SV" "$FIX/plugins/p" minor
  [ "$status" -eq 0 ]
  [[ "$output" == *"release-please manages this plugin"* ]]
  [[ "$output" == *"feat(<scope>):"* ]]
  [ "$(ver)" = "1.2.3" ] # unchanged
}

@test "standalone plugin is hand-bumped at the given level" {
  run "$SV" "$FIX/plugins/p" minor
  [ "$status" -eq 0 ]
  [[ "$output" == *"bumped p 1.2.3 -> 1.3.0"* ]]
  [ "$(ver)" = "1.3.0" ]
}

@test "standalone defaults to a patch bump" {
  run "$SV" "$FIX/plugins/p"
  [ "$status" -eq 0 ]
  [ "$(ver)" = "1.2.4" ]
}

@test "a major breaking hint is shown for release-please plugins" {
  printf '{"packages":{"plugins/p":{"release-type":"simple"}}}\n' \
    >"$FIX/release-please-config.json"
  run "$SV" "$FIX/plugins/p" major
  [[ "$output" == *"feat(<scope>)!:"* ]]
}

@test "rejects an invalid level" {
  run "$SV" "$FIX/plugins/p" sideways
  [ "$status" -ne 0 ]
  [[ "$output" == *"level must be"* ]]
}
