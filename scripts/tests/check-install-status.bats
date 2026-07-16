#!/usr/bin/env bats
#
# Tests for plugin-editor/scripts/check-install-status.sh. INSTALLED_PLUGINS_JSON
# points at a fixture so the real ~/.claude config is never read.

load helpers

setup() {
  CIS="$(repo_root_dir)/plugins/plugin-editor/scripts/check-install-status.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/plugins/p/.claude-plugin"
  printf '{"name":"test","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  printf '{"name":"p","version":"0.1.0","description":"t"}\n' >"$FIX/plugins/p/.claude-plugin/plugin.json"
  INSTALLED="$FIX/installed.json"
  export INSTALLED_PLUGINS_JSON="$INSTALLED"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "reports installed and suggests a reload when the plugin is active" {
  printf '{"version":1,"plugins":{"p@test":[{"scope":"user","version":"0.1.0","gitCommitSha":"abc1234","installPath":"/x"}]}}\n' >"$INSTALLED"
  run "$CIS" "$FIX/plugins/p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed (marketplace: test)"* ]]
  [[ "$output" == *"/plugin update p"* ]]
  [[ "$output" == *"/reload-plugins"* ]]
}

@test "reports not-installed when no record matches" {
  printf '{"version":1,"plugins":{"other@test":[{"scope":"user","version":"1.0.0"}]}}\n' >"$INSTALLED"
  run "$CIS" "$FIX/plugins/p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not installed"* ]]
  [[ "$output" != *"/reload-plugins"* ]]
}

@test "handles a missing installed_plugins.json" {
  run "$CIS" "$FIX/plugins/p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not installed"* ]]
}

@test "notes when the installed version differs from current" {
  printf '{"version":1,"plugins":{"p@test":[{"scope":"user","version":"0.0.9"}]}}\n' >"$INSTALLED"
  run "$CIS" "$FIX/plugins/p"
  [[ "$output" == *"version differs: current v0.1.0"* ]]
}

@test "--json emits installed + reloadSuggested" {
  printf '{"version":1,"plugins":{"p@test":[{"scope":"user","version":"0.1.0"}]}}\n' >"$INSTALLED"
  run "$CIS" "$FIX/plugins/p" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.installed' <<<"$output")" = "true" ]
  [ "$(jq -r '.reloadSuggested' <<<"$output")" = "true" ]
  [ "$(jq -r '.records | length' <<<"$output")" = "1" ]
}
