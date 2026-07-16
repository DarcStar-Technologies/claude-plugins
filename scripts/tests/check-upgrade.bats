#!/usr/bin/env bats
#
# Tests for the scaffold-upgrade plugin (plugins/scaffold-upgrade/scripts/check-upgrade.sh).
# Every case resolves templates LOCALLY — an ancestor-marketplace fixture or a
# local git repo carrying <name>-v* tags — so the suite never touches the network.
# The network-only paths (a bare `tag:`/`default:` source against the real GitHub
# repo) are exercised manually, matching the convention in forge-scaffold.bats.

load helpers

setup() {
  CHECK="$(repo_root_dir)/plugins/scaffold-upgrade/scripts/check-upgrade.sh"
  # Reuse the real semver engine via the override (no vendored copy to find).
  SEMVER_BIN="$(repo_root_dir)/plugins/semver/scripts/semver.sh"
  export SEMVER_BIN
  # A marketplace fixture with a `default` template.
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/templates/default/.claude-plugin"
  printf '{ "name":"t","owner":{"name":"t"},"plugins":[] }\n' >"$FIX/.claude-plugin/marketplace.json"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

# set_template <version> — the fixture template's current version.
set_template() {
  printf '{ "name":"default","version":"%s","description":"t" }\n' "$1" \
    >"$FIX/templates/default/.claude-plugin/plugin.json"
}

# add_scaffolded <name> <template> <templateVersion> [source] — a scaffolded plugin.
add_scaffolded() {
  local d="$FIX/plugins/$1"
  mkdir -p "$d/.claude-plugin"
  printf '{ "name":"%s","version":"0.1.0","description":"t" }\n' "$1" >"$d/.claude-plugin/plugin.json"
  jq -n --arg t "$2" --arg v "$3" --arg s "${4:-repo:.}" \
    '{template:$t, templateVersion:$v, source:$s, mode:"marketplace"}' \
    >"$d/.claude-plugin/scaffold.json"
}

@test "reports an upgrade when the template has advanced (minor)" {
  set_template 0.3.0
  add_scaffolded target default 0.2.0
  run "$CHECK" "$FIX/plugins/target"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UPGRADE AVAILABLE (minor: v0.2.0 -> v0.3.0)"* ]]
}

@test "reports up-to-date when the recorded version is the latest" {
  set_template 0.3.0
  add_scaffolded target default 0.3.0
  run "$CHECK" "$FIX/plugins/target"
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]
}

@test "classifies a major gap" {
  set_template 2.0.0
  add_scaffolded target default 1.5.0
  run "$CHECK" "$FIX/plugins/target"
  [[ "$output" == *"UPGRADE AVAILABLE (major:"* ]]
}

@test "reports 'ahead' when the recorded version is newer than latest" {
  set_template 0.1.0
  add_scaffolded target default 0.3.0
  run "$CHECK" "$FIX/plugins/target"
  [[ "$output" == *"ahead"* ]]
}

@test "errors clearly when the plugin has no scaffold provenance" {
  mkdir -p "$FIX/plugins/np/.claude-plugin"
  printf '{ "name":"np","version":"0.1.0","description":"t" }\n' >"$FIX/plugins/np/.claude-plugin/plugin.json"
  run "$CHECK" "$FIX/plugins/np"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no provenance"* ]]
}

@test "extracts only the newer sections from the template CHANGELOG" {
  set_template 0.3.0
  cat >"$FIX/templates/default/CHANGELOG.md" <<'MD'
# Changelog

## [0.3.0](x) (2026-01-02)

### Features
* the new thing

## [0.2.0](x) (2026-01-01)

### Features
* the old thing
MD
  add_scaffolded target default 0.2.0
  run "$CHECK" "$FIX/plugins/target"
  [[ "$output" == *"the new thing"* ]]
  [[ "$output" != *"the old thing"* ]]
}

@test "'what changed' skips a leading [Unreleased] section (Keep a Changelog order)" {
  set_template 0.3.0
  cat >"$FIX/templates/default/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Added
* unreleased-work

## [0.3.0](x) (2026-01-02)

### Features
* the-new-thing

## [0.2.0](x) (2026-01-01)

### Features
* the-old-thing
MD
  add_scaffolded target default 0.2.0
  run "$CHECK" "$FIX/plugins/target"
  [[ "$output" == *"the-new-thing"* ]]
  [[ "$output" != *"unreleased-work"* ]]
  [[ "$output" != *"the-old-thing"* ]]
}

@test "--json emits the expected shape" {
  set_template 0.3.0
  add_scaffolded target default 0.2.0
  run "$CHECK" "$FIX/plugins/target" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.status' <<<"$output")" = "upgrade-available" ]
  [ "$(jq -r '.gap' <<<"$output")" = "minor" ]
  [ "$(jq -r '.latestVersion' <<<"$output")" = "0.3.0" ]
  [ "$(jq -r '.template' <<<"$output")" = "default" ]
}

@test "resolves latest from <name>-v* release tags (local git repo, no network)" {
  local work
  work="$(mktemp -d)" # a plugin with NO marketplace ancestor -> forces tag resolution
  # an upstream repo carrying templates/default, tagged default-v0.1.0 then default-v0.4.0
  local repo="$work/upstream"
  mkdir -p "$repo/templates/default/.claude-plugin"
  git -C "$repo" init -q
  printf '{ "name":"default","version":"0.1.0","description":"t" }\n' >"$repo/templates/default/.claude-plugin/plugin.json"
  git -C "$repo" -c user.email=t@t -c user.name=t add -A
  git -C "$repo" -c user.email=t@t -c user.name=t commit -qm v01
  git -C "$repo" tag default-v0.1.0
  printf '{ "name":"default","version":"0.4.0","description":"t" }\n' >"$repo/templates/default/.claude-plugin/plugin.json"
  git -C "$repo" -c user.email=t@t -c user.name=t add -A
  git -C "$repo" -c user.email=t@t -c user.name=t commit -qm v04
  git -C "$repo" tag default-v0.4.0

  local pdir="$work/mytool"
  mkdir -p "$pdir/.claude-plugin"
  printf '{ "name":"mytool","version":"0.1.0","description":"t" }\n' >"$pdir/.claude-plugin/plugin.json"
  jq -n --arg s "default:$repo" \
    '{template:"default",templateVersion:"0.1.0",source:$s,mode:"portable"}' \
    >"$pdir/.claude-plugin/scaffold.json"

  run "$CHECK" "$pdir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"UPGRADE AVAILABLE"* ]]
  [[ "$output" == *"v0.4.0"* ]]
  rm -rf "$work"
}
