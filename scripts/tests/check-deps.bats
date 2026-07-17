#!/usr/bin/env bats
#
# Tests for dep-doctor/scripts/check-deps.sh — the deterministic, read-only dependency
# checker. Uses tools known to exist in the test env (bash, jq, python3) and a stub
# installed_plugins.json so nothing depends on the real environment.

load helpers

setup() {
  CD="$(repo_root_dir)/plugins/dep-doctor/scripts/check-deps.sh"
  FIX="$(mktemp -d)"
  printf '{"plugins":{"semver@darcstar":[{"scope":"project","version":"0.2.0"}]}}\n' >"$FIX/installed.json"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

status_of() { # <deps-json> <name> -> prints that dep's status
  printf '%s' "$1" | "$CD" 2>/dev/null | jq -r --arg n "$2" '.[] | select(.name==$n) | .status'
}

@test "cli present -> OK, absent -> MISSING" {
  local out
  out="$(printf '[{"kind":"cli","name":"jq"},{"kind":"cli","name":"nosuchtool-xyz"}]' | "$CD" || true)"
  [ "$(jq -r '.[0].status' <<<"$out")" = "OK" ]
  [ "$(jq -r '.[1].status' <<<"$out")" = "MISSING" ]
}

@test "cli version pattern: match -> OK, mismatch -> WRONG-VERSION" {
  [ "$(status_of '[{"kind":"cli","name":"bash","versionProbe":["--version"],"versionPattern":"version [0-9]"}]' bash)" = "OK" ]
  [ "$(status_of '[{"kind":"cli","name":"bash","versionProbe":["--version"],"versionPattern":"version 999"}]' bash)" = "WRONG-VERSION" ]
}

@test "library via python3: importable -> OK, missing -> MISSING" {
  command -v python3 >/dev/null 2>&1 || skip "python3 not available"
  [ "$(status_of '[{"kind":"library","name":"json","runtime":"python3","module":"json"}]' json)" = "OK" ]
  [ "$(status_of '[{"kind":"library","name":"nope","runtime":"python3","module":"nosuchmod_xyz"}]' nope)" = "MISSING" ]
}

@test "library module with shell metacharacters is NOT executed (UNKNOWN)" {
  local out
  out="$(printf '[{"kind":"library","name":"x","runtime":"python3","module":"os; print(1)"}]' | "$CD")"
  [ "$(jq -r '.[0].status' <<<"$out")" = "UNKNOWN" ]
  [[ "$(jq -r '.[0].detail' <<<"$out")" == *"not a plain identifier"* ]]
}

@test "plugin kind: present in installed_plugins.json -> OK, absent -> MISSING" {
  INSTALLED_PLUGINS_JSON="$FIX/installed.json" run bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"semver\"},{\"kind\":\"plugin\",\"name\":\"ghost\"}]" | "$0"' "$CD"
  [ "$status" -eq 1 ] # ghost is MISSING
  [ "$(jq -r '.[0].status' <<<"$output")" = "OK" ]
  [ "$(jq -r '.[1].status' <<<"$output")" = "MISSING" ]
}

@test "unknown kind -> UNKNOWN" {
  [ "$(status_of '[{"kind":"widget","name":"x"}]' x)" = "UNKNOWN" ]
}

@test "exit 0 when all OK, exit 1 when any MISSING" {
  printf '[{"kind":"cli","name":"jq"}]' | "$CD" >/dev/null
  run bash -c 'printf "%s" "[{\"kind\":\"cli\",\"name\":\"nosuchtool-xyz\"}]" | "$0" >/dev/null' "$CD"
  [ "$status" -eq 1 ]
}

@test "rejects non-array input" {
  run bash -c 'printf "%s" "{}" | "$0"' "$CD"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a JSON array"* ]]
}
