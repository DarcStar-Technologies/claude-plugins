#!/usr/bin/env bats
#
# Tests for plugin-editor/scripts/check-template.sh. Structure is delegated to
# edit-kit's check-structure.sh (resolved via the sibling edit-kit-path.sh, which
# finds the real edit-kit by walking up from the script's own location); the
# template-drift half is exercised with a stub check-upgrade, without the network.

load helpers

setup() {
  CT="$(repo_root_dir)/plugins/plugin-editor/scripts/check-template.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/p/.claude-plugin"
  printf '{"name":"p","version":"0.1.0","description":"t"}\n' >"$FIX/p/.claude-plugin/plugin.json"
  : >"$FIX/p/CONTEXT.md"
  : >"$FIX/p/README.md"
  printf '# Changelog\n\n## [Unreleased]\n' >"$FIX/p/CHANGELOG.md"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "passes structure and skips drift when there is no provenance" {
  run "$CT" "$FIX/p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"structure OK"* ]]
  [[ "$output" == *"no template provenance"* ]]
}

@test "fails when structure is broken (missing README)" {
  rm "$FIX/p/README.md"
  run "$CT" "$FIX/p"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing README.md"* ]]
}

@test "validates only the target plugin, not the whole repo" {
  # An ancestor with a check-all.sh that would fail loudly if it were run.
  mkdir -p "$FIX/scripts" "$FIX/plugins/target/.claude-plugin"
  printf '#!/usr/bin/env bash\necho WHOLE_REPO_CHECK_RAN\nexit 1\n' >"$FIX/scripts/check-all.sh"
  chmod +x "$FIX/scripts/check-all.sh"
  printf '{"name":"target","version":"0.1.0","description":"t"}\n' \
    >"$FIX/plugins/target/.claude-plugin/plugin.json"
  : >"$FIX/plugins/target/CONTEXT.md"
  : >"$FIX/plugins/target/README.md"
  printf '# Changelog\n\n## [Unreleased]\n' >"$FIX/plugins/target/CHANGELOG.md"
  run "$CT" "$FIX/plugins/target"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WHOLE_REPO_CHECK_RAN"* ]]  # the repo-wide check-all was NOT invoked
  [[ "$output" == *"structure OK (target)"* ]] # from edit-kit's check-structure.sh
}

@test "fails structure on a non-semver version" {
  jq '.version = "1.0"' "$FIX/p/.claude-plugin/plugin.json" >"$FIX/t" && mv "$FIX/t" "$FIX/p/.claude-plugin/plugin.json"
  run "$CT" "$FIX/p"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid semver"* ]]
}

@test "when edit-kit is absent, structure is skipped (warned) but drift still runs" {
  command -v check-structure.sh >/dev/null 2>&1 && skip "check-structure.sh is on PATH"
  local iso
  iso="$(mktemp -d)"
  local d="$iso"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/plugins/edit-kit/scripts" ]] && skip "an ancestor of the scratch dir holds edit-kit"
    d="$(dirname "$d")"
  done
  # Isolated copies of check-template.sh + its sibling resolver, so neither the target
  # nor the script's own location has an edit-kit ancestor.
  cp "$CT" "$iso/check-template.sh"
  cp "$(repo_root_dir)/plugins/plugin-editor/scripts/edit-kit-path.sh" "$iso/edit-kit-path.sh"
  mkdir -p "$iso/p/.claude-plugin"
  printf '{"name":"p","version":"0.1.0","description":"t"}\n' >"$iso/p/.claude-plugin/plugin.json"
  : >"$iso/p/CONTEXT.md"
  : >"$iso/p/README.md"
  printf '# Changelog\n\n## [Unreleased]\n' >"$iso/p/CHANGELOG.md"
  printf '{"template":"default","templateVersion":"0.1.0"}\n' >"$iso/p/.claude-plugin/scaffold.json"
  local stub="$iso/cu.sh"
  printf '#!/usr/bin/env bash\necho DRIFT_RAN\n' >"$stub"
  chmod +x "$stub"
  CHECK_UPGRADE_BIN="$stub" run bash "$iso/check-template.sh" "$iso/p"
  [ "$status" -ne 0 ]                            # structure couldn't run -> non-zero
  [[ "$output" == *"structure check skipped"* ]] # warned, not aborted
  [[ "$output" == *"DRIFT_RAN"* ]]               # the independent drift check STILL ran
  rm -rf "$iso"
}

@test "runs the drift check via check-upgrade when provenance exists" {
  printf '{"template":"default","templateVersion":"0.1.0","source":"repo:."}\n' \
    >"$FIX/p/.claude-plugin/scaffold.json"
  local stub="$FIX/cu.sh"
  # shellcheck disable=SC2016  # $1 is for the stub script, must stay literal
  printf '#!/usr/bin/env bash\necho "DRIFT_CHECK_RAN for $1"\n' >"$stub"
  chmod +x "$stub"
  CHECK_UPGRADE_BIN="$stub" run "$CT" "$FIX/p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"structure OK"* ]]
  [[ "$output" == *"DRIFT_CHECK_RAN for $FIX/p"* ]]
}
