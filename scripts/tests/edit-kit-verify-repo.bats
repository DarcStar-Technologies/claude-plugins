#!/usr/bin/env bats
#
# Tests for edit-kit/scripts/verify-repo.sh — post-apply cross-checks.
# Each test builds a throwaway fixture (a marketplace root with a plugin and a
# stub check-all.sh) so the real repo is never touched. The design is scoped +
# advisory: repo-wide check-all and the repo's centralized tests WARN but never
# block; only the plugin's own bundled tests are a hard failure.

load helpers

setup() {
  VR="$(repo_root_dir)/plugins/edit-kit/scripts/verify-repo.sh"
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

# --- section 1: repo-wide validation (advisory) --------------------------

@test "runs the repo's check-all.sh in a marketplace checkout and reports OK" {
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stub check-all ran"* ]]
  [[ "$output" == *"check-all.sh OK"* ]]
}

@test "a failing check-all.sh is advisory: warns but does NOT block" {
  cat >"$FIX/scripts/check-all.sh" <<'SH'
#!/usr/bin/env bash
echo "boom"
exit 1
SH
  chmod +x "$FIX/scripts/check-all.sh"
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"repo-wide checks failed"* ]]
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

@test "distinguishes a marketplace whose check-all.sh is missing" {
  rm -f "$FIX/scripts/check-all.sh"
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"marketplace found but scripts/check-all.sh is missing"* ]]
}

# --- section 2a: the plugin's own bundled tests (hard) -------------------

@test "runs the plugin's own bundled tests and passes" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  mkdir -p "$PDIR/scripts/tests"
  printf '#!/usr/bin/env bats\n@test "bundled ok" { true; }\n' >"$PDIR/scripts/tests/self.bats"
  run "$VR" "$PDIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bundled bats OK"* ]]
}

@test "fails (hard) when the plugin's own bundled test fails" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  mkdir -p "$PDIR/scripts/tests"
  printf '#!/usr/bin/env bats\n@test "bundled bad" { false; }\n' >"$PDIR/scripts/tests/self.bats"
  run "$VR" "$PDIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BUNDLED BATS FAILED"* ]]
}

# --- section 2b: the repo's centralized tests (advisory) ----------------

@test "runs the repo-root test named for a touched script and reports OK" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  printf '#!/usr/bin/env bats\n@test "ok" { true; }\n' >"$FIX/scripts/tests/foo.bats"
  printf '#!/usr/bin/env bash\ntrue\n' >"$PDIR/scripts/foo.sh"
  run "$VR" "$PDIR" scripts/foo.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"centralized bats OK"* ]]
}

@test "a failing centralized test is advisory: warns but does NOT block" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  printf '#!/usr/bin/env bats\n@test "bad" { false; }\n' >"$FIX/scripts/tests/foo.bats"
  printf '#!/usr/bin/env bash\ntrue\n' >"$PDIR/scripts/foo.sh"
  run "$VR" "$PDIR" scripts/foo.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"repo-root test"* ]]
}

@test "skips a centralized test when the touched script was removed" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  # A failing test that must NOT run because the script it covers is gone.
  printf '#!/usr/bin/env bats\n@test "should not run" { false; }\n' >"$FIX/scripts/tests/foo.bats"
  # scripts/foo.sh intentionally NOT created (the edit removed it).
  run "$VR" "$PDIR" scripts/foo.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"no bats tests found"* ]]
  [[ "$output" != *"centralized"* ]]
}

@test "normalizes ./-prefixed and plugin-dir-prefixed touched paths (and dedups)" {
  command -v bats >/dev/null 2>&1 || skip "bats not installed"
  printf '#!/usr/bin/env bats\n@test "ok" { true; }\n' >"$FIX/scripts/tests/foo.bats"
  printf '#!/usr/bin/env bash\ntrue\n' >"$PDIR/scripts/foo.sh"
  run "$VR" "$PDIR" "./scripts/foo.sh" "$PDIR/scripts/foo.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"centralized bats OK"* ]]
}
