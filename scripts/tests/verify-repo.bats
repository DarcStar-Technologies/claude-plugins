#!/usr/bin/env bats
#
# Tests for plugin-editor/scripts/verify-repo.sh — post-apply repo verification.
# Each test builds a throwaway fixture (a marketplace root with a plugin and a
# stub check-all.sh) so the real repo is never touched.

load helpers

setup() {
  VR="$(repo_root_dir)/plugins/plugin-editor/scripts/verify-repo.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/plugins/p/.claude-plugin" \
    "$FIX/plugins/p/scripts" "$FIX/scripts" "$FIX/scripts/tests"
  printf '{"name":"test","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  printf '{"name":"p","version":"0.1.0","description":"t"}\n' >"$FIX/plugins/p/.claude-plugin/plugin.json"
  # Default stub check-all.sh: passes.
  cat >"$FIX/scripts/check-all.sh" <<'SH'
#!/usr/bin/env bash
echo "stub check-all ran"
exit 0
SH
  chmod +x "$FIX/scripts/check-all.sh"
  PDIR="$FIX/plugins/p"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "runs the repo's check-all.sh in a marketplace checkout and passes" {
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub check-all ran"* ]]
  [[ "$output" == *"check-all.sh OK"* ]]
}

@test "fails when the repo's check-all.sh fails" {
  cat >"$FIX/scripts/check-all.sh" <<'SH'
#!/usr/bin/env bash
echo "boom"
exit 1
SH
  chmod +x "$FIX/scripts/check-all.sh"
  run "$VR" "$PDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CHECK-ALL FAILED"* ]]
}

@test "skips repo-wide validation cleanly outside a marketplace" {
  local solo
  solo="$(mktemp -d)"
  mkdir -p "$solo/.claude-plugin" "$solo/scripts"
  printf '{"name":"s","version":"0.1.0","description":"t"}\n' >"$solo/.claude-plugin/plugin.json"
  run "$VR" "$solo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not in a marketplace repo"* ]]
  rm -rf "$solo"
}

@test "shellchecks a touched clean script and passes" {
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
  printf '#!/usr/bin/env bash\necho "hello"\n' >"$PDIR/scripts/ok.sh"
  run "$VR" "$PDIR" scripts/ok.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"shellcheck OK"* ]]
}

@test "fails when a touched script has a shellcheck problem" {
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"
  # `local` outside a function is an error-level finding (SC2168), so this fails
  # regardless of any local ~/.shellcheckrc that mutes lower-severity checks.
  printf '#!/usr/bin/env bash\nlocal x=1\n' >"$PDIR/scripts/bad.sh"
  run "$VR" "$PDIR" scripts/bad.sh
  [ "$status" -eq 1 ]
}

@test "skips shellcheck cleanly when no touched scripts are passed" {
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no touched scripts"* ]]
}

@test "runs the repo-root bats test named for a touched script (passing)" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  printf '#!/usr/bin/env bats\n@test "ok" { true; }\n' >"$FIX/scripts/tests/foo.bats"
  printf '#!/usr/bin/env bash\ntrue\n' >"$PDIR/scripts/foo.sh"
  run "$VR" "$PDIR" scripts/foo.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats OK"* ]]
}

@test "fails when a touched script's repo-root bats test fails" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  printf '#!/usr/bin/env bats\n@test "bad" { false; }\n' >"$FIX/scripts/tests/foo.bats"
  printf '#!/usr/bin/env bash\ntrue\n' >"$PDIR/scripts/foo.sh"
  run "$VR" "$PDIR" scripts/foo.sh
  [ "$status" -eq 1 ]
}

@test "runs a plugin's own bundled bats tests" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  mkdir -p "$PDIR/scripts/tests"
  printf '#!/usr/bin/env bats\n@test "bundled ok" { true; }\n' >"$PDIR/scripts/tests/self.bats"
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bats OK"* ]]
}
