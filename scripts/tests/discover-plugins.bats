#!/usr/bin/env bats
#
# Tests for dep-doctor/scripts/discover-plugins.sh — the picker discovery step. Builds a
# throwaway marketplace fixture so the real repo is untouched.

load helpers

setup() {
  DP="$(repo_root_dir)/plugins/dep-doctor/scripts/discover-plugins.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/plugins/alpha/.claude-plugin" \
    "$FIX/plugins/beta/.claude-plugin" "$FIX/sub"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  printf '{"name":"alpha","version":"0.1.0","description":"Alpha."}\n' >"$FIX/plugins/alpha/.claude-plugin/plugin.json"
  printf '{"name":"beta","version":"0.2.0","description":"Beta."}\n' >"$FIX/plugins/beta/.claude-plugin/plugin.json"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "lists plugins with absolute paths" {
  run "$DP" "$FIX"
  [ "$status" -eq 0 ]
  names="$(printf '%s' "$output" | jq -r '[.[].name] | join(",")')"
  [ "$names" = "alpha,beta" ]
  paths="$(printf '%s' "$output" | jq -r '.[].path')"
  [[ "$paths" == *"/plugins/alpha"* ]]
  [[ "$paths" == *"/plugins/beta"* ]]
}

@test "finds the marketplace from a subdirectory" {
  run "$DP" "$FIX/sub"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/plugins/alpha"* ]]
}

@test "exits 2 with no output when no marketplace ancestor is found" {
  local solo
  solo="$(mktemp -d)"
  local d="$solo"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/.claude-plugin/marketplace.json" ]] && skip "scratch dir has a marketplace ancestor"
    d="$(dirname "$d")"
  done
  run "$DP" "$solo"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  rm -rf "$solo"
}

@test "prints [] when the marketplace has no plugins/ dir" {
  rm -rf "$FIX/plugins"
  run "$DP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "skips a directory with an unparseable manifest" {
  printf 'not json\n' >"$FIX/plugins/alpha/.claude-plugin/plugin.json"
  run "$DP" "$FIX"
  [ "$status" -eq 0 ]
  names="$(printf '%s' "$output" | jq -r '[.[].name] | join(",")')"
  [ "$names" = "beta" ]
}
