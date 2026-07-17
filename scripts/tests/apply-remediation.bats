#!/usr/bin/env bats
#
# Tests for dep-doctor/scripts/apply-remediation.sh — the confirmation-gated installer.
# These NEVER install anything: they exercise --dry-run and the refusal paths (the
# security guarantees), so the suite is safe and hermetic.

load helpers

setup() { AR="$(repo_root_dir)/plugins/dep-doctor/scripts/apply-remediation.sh"; }

@test "dry-run prints the exact command for an allow-listed installer, installs nothing" {
  command -v npm >/dev/null 2>&1 || skip "npm not available"
  run bash -c 'printf "%s" "[{\"installer\":\"npm\",\"package\":\"prettier\"}]" | "$0" --dry-run' "$AR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN: npm install -g prettier"* ]]
}

@test "refuses a non-allow-listed installer (apt)" {
  run bash -c 'printf "%s" "[{\"installer\":\"apt\",\"package\":\"foo\"}]" | "$0" --dry-run' "$AR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not allow-listed"* ]]
}

@test "refuses sudo" {
  run bash -c 'printf "%s" "[{\"installer\":\"sudo\",\"package\":\"foo\"}]" | "$0" --dry-run' "$AR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not allow-listed"* ]]
}

@test "refuses a package name with shell metacharacters" {
  run bash -c 'printf "%s" "[{\"installer\":\"npm\",\"package\":\"foo; rm -rf ~\"}]" | "$0" --dry-run' "$AR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a plain package name"* ]]
}

@test "an empty action list succeeds and does nothing" {
  run bash -c 'printf "%s" "[]" | "$0" --dry-run' "$AR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rejects non-array input" {
  run bash -c 'printf "%s" "{}" | "$0" --dry-run' "$AR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a JSON array"* ]]
}

@test "reports the installer is missing rather than running something else" {
  run bash -c 'printf "%s" "[{\"installer\":\"cargo\",\"package\":\"ripgrep\"}]" | "$0" --dry-run' "$AR"
  command -v cargo >/dev/null 2>&1 && skip "cargo is installed"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cargo not installed"* ]]
}
