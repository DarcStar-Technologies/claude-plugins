#!/usr/bin/env bats
#
# Tests for plugin-editor/scripts/list-plugins.sh.

load helpers

setup() {
  LP="$(repo_root_dir)/plugins/plugin-editor/scripts/list-plugins.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin"
  printf '{"name":"mkt","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  mkdir -p "$FIX/plugins"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

add() { # <name> <description>
  mkdir -p "$FIX/plugins/$1/.claude-plugin"
  jq -n --arg n "$1" --arg d "$2" '{name:$n, version:"0.1.0", description:$d}' \
    >"$FIX/plugins/$1/.claude-plugin/plugin.json"
}

@test "lists plugins under a marketplace as JSON {name, path, description}" {
  add alpha "the alpha plugin"
  add beta "the beta plugin"
  run "$LP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'length' <<<"$output")" = "2" ]
  [ "$(jq -r '.[0].name' <<<"$output")" = "alpha" ]
  [ "$(jq -r '.[0].path' <<<"$output")" = "plugins/alpha" ]
  [ "$(jq -r '.[0].description' <<<"$output")" = "the alpha plugin" ]
}

@test "skips directories without a plugin.json" {
  add real "real"
  mkdir -p "$FIX/plugins/not-a-plugin"
  run "$LP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'length' <<<"$output")" = "1" ]
  [ "$(jq -r '.[0].name' <<<"$output")" = "real" ]
}

@test "skips a plugin with a malformed plugin.json instead of aborting" {
  add good "the good one"
  mkdir -p "$FIX/plugins/broken/.claude-plugin"
  printf '{ not valid json\n' >"$FIX/plugins/broken/.claude-plugin/plugin.json"
  run "$LP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'length' <<<"$output")" = "1" ]
  [ "$(jq -r '.[0].name' <<<"$output")" = "good" ]
}

@test "resolves the marketplace from a nested search root" {
  add gamma "g"
  mkdir -p "$FIX/plugins/gamma/scripts"
  run "$LP" "$FIX/plugins/gamma/scripts"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].name' <<<"$output")" = "gamma" ]
}

@test "exits non-zero (no output) when there is no marketplace ancestor" {
  local bare
  bare="$(mktemp -d)"
  run "$LP" "$bare"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  rm -rf "$bare"
}

@test "prints [] when the marketplace has no valid plugins" {
  run "$LP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}
