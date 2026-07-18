#!/usr/bin/env bats
#
# Tests for the scaffold-retarget plugin's deterministic scripts. Everything runs
# LOCALLY — a fixture marketplace + a local git "upstream" carrying tagged template
# versions — so the suite never touches the network.

load helpers

setup() {
  SR="$(repo_root_dir)/plugins/scaffold-retarget/scripts"
  SEMVER_BIN="$(repo_root_dir)/plugins/semver/scripts/semver.sh"
  export SEMVER_BIN
  W="$(mktemp -d)"
  # A fixture marketplace root.
  MP="$W/mkt"
  mkdir -p "$MP/.claude-plugin"
  printf '{ "name":"t","owner":{"name":"t"},"plugins":[] }\n' >"$MP/.claude-plugin/marketplace.json"
}
teardown() { [[ -n "${W:-}" ]] && rm -rf "$W"; }

# add_plugin_with_provenance <name> — a scaffolded plugin under the fixture marketplace.
add_plugin_with_provenance() {
  local d="$MP/plugins/$1"
  mkdir -p "$d/.claude-plugin"
  printf '{ "name":"%s","version":"0.1.0","description":"desc" }\n' "$1" >"$d/.claude-plugin/plugin.json"
  printf '{ "template":"demo","templateVersion":"0.1.0","source":"repo:%s","mode":"marketplace" }\n' \
    "${2:-$W/upstream}" >"$d/.claude-plugin/scaffold.json"
}

# build_upstream — a local git repo with template 'demo' tagged demo--v0.1.0 and demo--v0.2.0.
# v0.2.0 CHANGES commands/go.md and ADDS commands/extra.md.
build_upstream() {
  local r="$W/upstream"
  mkdir -p "$r/templates/demo/.claude-plugin" "$r/templates/demo/commands"
  printf '{ "name":"demo","version":"0.1.0","description":"d" }\n' >"$r/templates/demo/.claude-plugin/plugin.json"
  printf '# {{NAME}} v1\n\n{{DESC}}\n' >"$r/templates/demo/commands/go.md"
  git -C "$r" init -q
  git -C "$r" -c user.email=t@t -c user.name=t add -A
  git -C "$r" -c user.email=t@t -c user.name=t commit -qm v1
  git -C "$r" tag demo--v0.1.0
  printf '{ "name":"demo","version":"0.2.0","description":"d" }\n' >"$r/templates/demo/.claude-plugin/plugin.json"
  printf '# {{NAME}} v2 CHANGED\n\n{{DESC}}\n' >"$r/templates/demo/commands/go.md"
  printf '# {{NAME}} extra\n' >"$r/templates/demo/commands/extra.md"
  git -C "$r" -c user.email=t@t -c user.name=t add -A
  git -C "$r" -c user.email=t@t -c user.name=t commit -qm v2
  git -C "$r" tag demo--v0.2.0
  git -C "$r" checkout -q demo--v0.1.0 # working tree at v0.1.0
  printf '%s' "$r"
}

# --- discover-targets.sh ---------------------------------------------------

@test "discover-targets lists only plugins with scaffold provenance" {
  add_plugin_with_provenance scaffolded
  mkdir -p "$MP/plugins/bare/.claude-plugin" # no scaffold.json
  printf '{ "name":"bare","version":"0.1.0","description":"x" }\n' >"$MP/plugins/bare/.claude-plugin/plugin.json"
  run "$SR/discover-targets.sh" "$MP"
  [ "$status" -eq 0 ]
  [ "$(jq -r 'map(.name) | sort | join(",")' <<<"$output")" = "scaffolded" ]
}

@test "discover-targets exits 2 (no output) outside a marketplace" {
  run "$SR/discover-targets.sh" "$W"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

# --- resolve-template-version.sh -------------------------------------------

@test "resolve a specific version from the ancestor marketplace when it matches" {
  # the fixture marketplace itself carries templates/demo at 0.5.0
  mkdir -p "$MP/templates/demo/.claude-plugin"
  printf '{ "name":"demo","version":"0.5.0","description":"d" }\n' >"$MP/templates/demo/.claude-plugin/plugin.json"
  add_plugin_with_provenance p
  run "$SR/resolve-template-version.sh" demo 0.5.0 --from "$MP/plugins/p"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.version' <<<"$output")" = "0.5.0" ]
  [[ "$(jq -r '.resolvedFrom' <<<"$output")" == marketplace:* ]]
  [ "$(jq -r '.cleanupPath' <<<"$output")" = "null" ] # existing dir, not a throwaway clone
}

@test "resolve an arbitrary version by cloning its release tag" {
  local repo
  repo="$(build_upstream)"
  run "$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.version' <<<"$output")" = "0.2.0" ]
  [[ "$(jq -r '.resolvedFrom' <<<"$output")" == tags:* ]]
  [ "$(jq -r '.cleanupPath' <<<"$output")" != "null" ] # a throwaway clone the caller cleans
  rm -rf "$(jq -r '.cleanupPath' <<<"$output")"
}

@test "resolve rejects a non-semver version" {
  run "$SR/resolve-template-version.sh" demo not-a-version --from "$W"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid semver"* ]]
}

# --- diff-components.sh (3-way) --------------------------------------------

@test "3-way diff: update, add, keep, unchanged, and conflict are classified" {
  local repo bdir tdir
  repo="$(build_upstream)"
  local base tgt
  base="$("$SR/resolve-template-version.sh" demo 0.1.0 --from "$W" --source "repo:$repo")"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  bdir="$(jq -r .dir <<<"$base")"
  tdir="$(jq -r .dir <<<"$tgt")"

  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  mkdir -p "$pd/commands"
  printf '# mytool v1\n\ndesc\n' >"$pd/commands/go.md" # == base rendered -> update
  printf '# mytool custom\n' >"$pd/commands/mine.md"   # local-add -> keep

  run "$SR/diff-components.sh" --base "$bdir" --current "$pd" --target "$tdir" --name mytool --desc "desc"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[] | select(.path=="commands/go.md") | .action' <<<"$output")" = "update" ]
  [ "$(jq -r '.[] | select(.path=="commands/extra.md") | .action' <<<"$output")" = "add" ]
  [ "$(jq -r '.[] | select(.path=="commands/mine.md") | .action' <<<"$output")" = "keep" ]

  # Now customize go.md so it diverges from BOTH base and target -> conflict.
  printf '# mytool HAND EDITED\n' >"$pd/commands/go.md"
  run "$SR/diff-components.sh" --base "$bdir" --current "$pd" --target "$tdir" --name mytool --desc "desc"
  [ "$(jq -r '.[] | select(.path=="commands/go.md") | .action' <<<"$output")" = "conflict" ]

  rm -rf "$(jq -r '.cleanupPath' <<<"$base")" "$(jq -r '.cleanupPath' <<<"$tgt")"
}

# --- apply-retarget.sh -----------------------------------------------------

@test "apply renders updates with the plugin's identity, bumps provenance, logs CHANGELOG" {
  local repo tgt tdir
  repo="$(build_upstream)"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  mkdir -p "$pd/commands"
  printf '# mytool v1\n\ndesc\n' >"$pd/commands/go.md"
  printf '# Changelog\n\n## [Unreleased]\n' >"$pd/CHANGELOG.md"

  run "$SR/apply-retarget.sh" --plugin "$pd" --target "$tdir" --name mytool --desc "desc" \
    --to-version 0.2.0 --from-version 0.1.0 \
    --decisions '[{"path":"commands/go.md","action":"update"},{"path":"commands/extra.md","action":"add"}]'
  [ "$status" -eq 0 ]
  grep -q 'v2 CHANGED' "$pd/commands/go.md"   # updated to target
  grep -q 'mytool' "$pd/commands/go.md"       # identity preserved
  run grep -q '{{NAME}}' "$pd/commands/go.md" # no leftover placeholder
  [ "$status" -ne 0 ]
  [ -f "$pd/commands/extra.md" ] # added
  [ "$(jq -r '.templateVersion' "$pd/.claude-plugin/scaffold.json")" = "0.2.0" ]
  grep -q 'Retarget from demo v0.1.0 to v0.2.0' "$pd/CHANGELOG.md"
  grep -q '### Changed' "$pd/CHANGELOG.md"

  rm -rf "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "apply refuses an unsafe or out-of-scope decision path" {
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  run "$SR/apply-retarget.sh" --plugin "$pd" --target "$W" --name mytool --desc "d" \
    --to-version 0.2.0 --decisions '[{"path":"../evil.md","action":"update"}]'
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsafe or out-of-scope"* ]]
}

@test "render terminates and is literal when the description contains {{DESC}}" {
  # Regression: a naive re-scanning loop would spin forever on a desc that is the token.
  local repo tgt tdir
  repo="$(build_upstream)"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  mkdir -p "$pd/commands"
  printf '# Changelog\n\n## [Unreleased]\n' >"$pd/CHANGELOG.md"
  run timeout 20 "$SR/apply-retarget.sh" --plugin "$pd" --target "$tdir" --name mytool \
    --desc '{{DESC}}' --to-version 0.2.0 --from-version 0.1.0 \
    --decisions '[{"path":"commands/go.md","action":"add"}]'
  [ "$status" -eq 0 ]                      # did not hang / time out
  grep -qF '{{DESC}}' "$pd/commands/go.md" # the literal desc landed exactly once
  rm -rf "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "resolve with a local: source does NOT fall back to cloning the default repo" {
  # Even though the default repo HAS the version, a local: source that can't resolve
  # must fail — never silently pull same-named content from the public upstream.
  local repo
  repo="$(build_upstream)"
  SCAFFOLD_RETARGET_DEFAULT_REPO="$repo" run "$SR/resolve-template-version.sh" demo 0.2.0 \
    --from "$W" --source "local:$W/does-not-exist"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not resolve"* ]]
}

@test "apply refuses to write through a symlink escaping the plugin dir" {
  local repo tgt tdir
  repo="$(build_upstream)"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  mkdir -p "$pd/commands"
  printf 'SECRET\n' >"$W/outside.md"
  ln -s "$W/outside.md" "$pd/commands/go.md" # a symlink escaping the plugin
  run "$SR/apply-retarget.sh" --plugin "$pd" --target "$tdir" --name mytool --desc d \
    --to-version 0.2.0 --decisions '[{"path":"commands/go.md","action":"update"}]'
  [ "$status" -ne 0 ]
  [[ "$output" == *"symlink"* ]]
  [ "$(cat "$W/outside.md")" = "SECRET" ] # the external file was NOT overwritten
  rm -rf "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "3-way diff: a locally-deleted file the target still ships is a conflict, not an add" {
  local repo bdir tdir base tgt
  repo="$(build_upstream)"
  base="$("$SR/resolve-template-version.sh" demo 0.1.0 --from "$W" --source "repo:$repo")"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  bdir="$(jq -r .dir <<<"$base")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  mkdir -p "$pd/commands" # go.md exists in base+target but NOT in the plugin (deleted)
  run "$SR/diff-components.sh" --base "$bdir" --current "$pd" --target "$tdir" --name mytool --desc d
  [ "$(jq -r '.[] | select(.path=="commands/go.md") | .action' <<<"$output")" = "conflict" ]
  rm -rf "$(jq -r '.cleanupPath' <<<"$base")" "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "updated files keep a trailing newline (end-of-file-fixer clean)" {
  local repo tgt tdir
  repo="$(build_upstream)"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  mkdir -p "$pd/commands"
  printf '# mytool v1\n\ndesc\n' >"$pd/commands/go.md"
  "$SR/apply-retarget.sh" --plugin "$pd" --target "$tdir" --name mytool --desc desc \
    --to-version 0.2.0 --decisions '[{"path":"commands/go.md","action":"update"}]' >/dev/null
  [ -z "$(tail -c1 "$pd/commands/go.md")" ] # last byte is a newline
  rm -rf "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "CHANGELOG bullet is written even when ### Changed is the final line" {
  local repo tgt tdir
  repo="$(build_upstream)"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  printf '# Changelog\n\n## [Unreleased]\n\n### Changed\n' >"$pd/CHANGELOG.md" # heading is last line
  "$SR/apply-retarget.sh" --plugin "$pd" --target "$tdir" --name mytool --desc d \
    --to-version 0.2.0 --from-version 0.1.0 --decisions '[]' >/dev/null
  grep -q 'Retarget from demo' "$pd/CHANGELOG.md"
  rm -rf "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "apply does NOT create a duplicate ### Changed when one already exists" {
  local repo tgt tdir
  repo="$(build_upstream)"
  tgt="$("$SR/resolve-template-version.sh" demo 0.2.0 --from "$W" --source "repo:$repo")"
  tdir="$(jq -r .dir <<<"$tgt")"
  add_plugin_with_provenance mytool
  local pd="$MP/plugins/mytool"
  printf '# Changelog\n\n## [Unreleased]\n\n### Changed\n\n- pre-existing bullet\n' >"$pd/CHANGELOG.md"
  run "$SR/apply-retarget.sh" --plugin "$pd" --target "$tdir" --name mytool --desc "d" \
    --to-version 0.2.0 --from-version 0.1.0 --decisions '[]'
  [ "$status" -eq 0 ]
  [ "$(grep -c '^### Changed' "$pd/CHANGELOG.md")" -eq 1 ] # not duplicated
  grep -q 'pre-existing bullet' "$pd/CHANGELOG.md"
  rm -rf "$(jq -r '.cleanupPath' <<<"$tgt")"
}

@test "provider-path.sh resolves the plan-kit provider via a marketplace ancestor" {
  # The command resolves plan-kit's validate-plan.sh at run time to gate the planner's
  # JSON plan; smoke-test that this plugin's bundled resolver finds the provider.
  unset PLAN_KIT_DIR
  mkdir -p "$MP/plugins/plan-kit/scripts" "$MP/sub/deep"
  printf '#!/usr/bin/env bash\ntrue\n' >"$MP/plugins/plan-kit/scripts/validate-plan.sh"
  run "$SR/provider-path.sh" plan-kit validate-plan.sh --from "$MP/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$MP/plugins/plan-kit/scripts" ]
}

@test "the planner's action vocabulary validates against plan-kit's --actions" {
  # The whole reason validate-plan.sh is parameterized: this plugin's plans use
  # add/keep/update/delete, which the command wires as --actions. Lock that contract —
  # the vocabulary must be accepted, and the default create/modify/delete must reject it.
  local vp
  vp="$(repo_root_dir)/plugins/plan-kit/scripts/validate-plan.sh"
  local plan='{"summary":"s","actions":[{"path":"commands/x.md","action":"update"},{"path":"y.md","action":"add"},{"path":"z.sh","action":"keep"},{"path":"w.md","action":"delete"}],"risks":[],"questions":[]}'
  run bash -c 'printf "%s" "$2" | "$1" --actions add,keep,update,delete' _ "$vp" "$plan"
  [ "$status" -eq 0 ]
  run bash -c 'printf "%s" "$2" | "$1"' _ "$vp" "$plan" # default vocabulary
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be one of: create, modify, delete"* ]]
}
