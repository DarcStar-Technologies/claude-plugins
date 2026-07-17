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
  [ "$(status_of '[{"kind":"cli","name":"bash","versionFlag":"--version","versionPattern":"version [0-9]"}]' bash)" = "OK" ]
  [ "$(status_of '[{"kind":"cli","name":"bash","versionFlag":"--version","versionPattern":"version 999"}]' bash)" = "WRONG-VERSION" ]
}

@test "a non-allow-listed versionFlag is NOT executed (UNKNOWN, no code run)" {
  rm -f "$FIX/pwned"
  local out
  out="$(printf '[{"kind":"cli","name":"bash","versionFlag":"-c","versionPattern":".","x":"touch %s/pwned"}]' "$FIX" | "$CD" || true)"
  [ "$(jq -r '.[0].status' <<<"$out")" = "UNKNOWN" ]
  [[ "$(jq -r '.[0].detail' <<<"$out")" == *"not allow-listed"* ]]
  [ ! -e "$FIX/pwned" ]
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

@test "plugin with only a stale/empty record -> MISSING, not OK" {
  printf '{"plugins":{"empty@m":[],"real@m":[{"scope":"project"}]}}\n' >"$FIX/ip.json"
  INSTALLED_PLUGINS_JSON="$FIX/ip.json" run bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"empty\"},{\"kind\":\"plugin\",\"name\":\"real\"}]" | "$0"' "$CD"
  [ "$(jq -r '.[] | select(.name=="empty") | .status' <<<"$output")" = "MISSING" ]
  [ "$(jq -r '.[] | select(.name=="real") | .status' <<<"$output")" = "OK" ]
}

@test "plugin bare (no version range) reports the installed version in detail" {
  INSTALLED_PLUGINS_JSON="$FIX/installed.json" run bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"semver\"}]" | "$0"' "$CD"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].status' <<<"$output")" = "OK" ]
  [[ "$(jq -r '.[0].detail' <<<"$output")" == *"v0.2.0"* ]]
}

@test "plugin version range: satisfied -> OK, unsatisfied -> WRONG-VERSION (exit 1)" {
  INSTALLED_PLUGINS_JSON="$FIX/installed.json" run bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"semver\",\"version\":\">=0.1.0\"}]" | "$0"' "$CD"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].status' <<<"$output")" = "OK" ]
  INSTALLED_PLUGINS_JSON="$FIX/installed.json" run bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"semver\",\"version\":\">=0.3.0\"}]" | "$0"' "$CD"
  [ "$status" -eq 1 ]
  [ "$(jq -r '.[0].status' <<<"$output")" = "WRONG-VERSION" ]
}

plugin_range_status() { # <range> -> prints the status for semver@0.2.0 vs <range>
  INSTALLED_PLUGINS_JSON="$FIX/installed.json" bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"semver\",\"version\":\"'"$1"'\"}]" | "$0"' "$CD" |
    jq -r '.[0].status'
}

@test "plugin caret satisfied: ^0.2.0 vs installed 0.2.0 -> OK" {
  [ "$(plugin_range_status '^0.2.0')" = "OK" ]
}

@test "plugin caret unsatisfied: ^0.1.0 vs installed 0.2.0 -> WRONG-VERSION" {
  [ "$(plugin_range_status '^0.1.0')" = "WRONG-VERSION" ]
}

@test "plugin tilde satisfied: ~0.2.0 vs installed 0.2.0 -> OK" {
  [ "$(plugin_range_status '~0.2.0')" = "OK" ]
}

@test "plugin installed without a recorded version + a range -> UNKNOWN (not a false WRONG-VERSION)" {
  printf '{"plugins":{"nover@m":[{"scope":"project"}]}}\n' >"$FIX/nv.json"
  INSTALLED_PLUGINS_JSON="$FIX/nv.json" run bash -c \
    'printf "%s" "[{\"kind\":\"plugin\",\"name\":\"nover\",\"version\":\">=1.0.0\"}]" | "$0"' "$CD"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].status' <<<"$output")" = "UNKNOWN" ]
}

@test "plugin range degrades to UNKNOWN when the semver engine cannot be resolved" {
  # Run a COPY from an isolated dir (no marketplace ancestor) with SEMVER_BIN unset, so the
  # engine resolver finds nothing (semver.sh is not on PATH) and range evaluation has no
  # engine — it must degrade to UNKNOWN, never a false WRONG-VERSION.
  cp "$CD" "$FIX/check-deps.sh"
  printf '{"plugins":{"semver@m":[{"scope":"project","version":"0.2.0"}]}}\n' >"$FIX/ip.json"
  INSTALLED_PLUGINS_JSON="$FIX/ip.json" run bash -c \
    'unset SEMVER_BIN; printf "%s" "[{\"kind\":\"plugin\",\"name\":\"semver\",\"version\":\">=0.3.0\"}]" | "$0"' "$FIX/check-deps.sh"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].status' <<<"$output")" = "UNKNOWN" ]
}

@test "unknown kind -> UNKNOWN" {
  [ "$(status_of '[{"kind":"widget","name":"x"}]' x)" = "UNKNOWN" ]
}

@test "a non-object array element is rejected cleanly (no jq crash)" {
  run bash -c 'printf "%s" "[\"jq\"]" | "$0"' "$CD"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a JSON object"* ]]
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
