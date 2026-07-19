#!/usr/bin/env bats
#
# Tests for provider-path.sh — the one generic locator every provider consumer vendors to
# resolve a provider plugin's scripts dir ($<PROVIDER>_DIR -> marketplace ancestor ->
# PATH). Parameterized by provider name + the required files a candidate dir must hold, so
# it replaces the per-provider edit-kit-path.sh / plan-kit-path.sh resolvers. The vendored
# copies are byte-identical; this exercises the canonical one under templates/.

load helpers

# Files that stand in for the two real providers' toolkits.
EDIT_KIT_FILES="check-structure.sh update-changelog.sh sync-version.sh scaffold-test.sh verify-repo.sh lib/plan-paths.sh"

write_files() { # <dir> <file>...
  local dir="$1"
  shift
  local f
  for f in "$@"; do
    mkdir -p "$(dirname "$dir/$f")"
    printf '#!/usr/bin/env bash\ntrue\n' >"$dir/$f"
  done
}

setup() {
  # Overrides in the runner env would win tier 1 and defeat the ancestor assertions.
  unset PLAN_KIT_DIR EDIT_KIT_DIR
  PP="$(repo_root_dir)/templates/plan-confirm-apply/scripts/provider-path.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/sub/deep"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  write_files "$FIX/plugins/plan-kit/scripts" validate-plan.sh
  # shellcheck disable=SC2086
  write_files "$FIX/plugins/edit-kit/scripts" $EDIT_KIT_FILES
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "resolves a single-file provider (plan-kit) via the marketplace ancestor" {
  run "$PP" plan-kit validate-plan.sh --from "$FIX/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ]
}

@test "resolves a multi-file provider (edit-kit) via the marketplace ancestor" {
  # shellcheck disable=SC2086
  run "$PP" edit-kit $EDIT_KIT_FILES --from "$FIX/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/edit-kit/scripts" ]
}

@test "honors the derived override var (PLAN_KIT_DIR for plan-kit)" {
  local other
  other="$(mktemp -d)"
  write_files "$other" validate-plan.sh
  PLAN_KIT_DIR="$other" run "$PP" plan-kit validate-plan.sh --from "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$other" ]
  rm -rf "$other"
}

@test "derives a different override var per provider (EDIT_KIT_DIR for edit-kit)" {
  local other
  other="$(mktemp -d)"
  # shellcheck disable=SC2086
  write_files "$other" $EDIT_KIT_FILES
  # shellcheck disable=SC2086
  EDIT_KIT_DIR="$other" run "$PP" edit-kit $EDIT_KIT_FILES --from "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$other" ]
  rm -rf "$other"
}

@test "an override missing a required file falls through to the ancestor" {
  local partial
  partial="$(mktemp -d)" # empty -> no validate-plan.sh
  PLAN_KIT_DIR="$partial" run "$PP" plan-kit validate-plan.sh --from "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ]
  rm -rf "$partial"
}

@test "--from=DIR (equals form) is accepted" {
  run "$PP" plan-kit validate-plan.sh --from="$FIX/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ]
}

@test "--from with no following value is rejected" {
  run "$PP" plan-kit validate-plan.sh --from
  [ "$status" -ne 0 ]
  [[ "$output" == *"--from needs a value"* ]]
}

@test "all four vendored provider-path.sh copies are byte-identical" {
  # The bootstrap resolver is vendored per consumer; a divergent copy would resolve
  # providers by different rules. Pin them to the canonical (template) copy.
  local canonical rel
  canonical="$(repo_root_dir)/templates/plan-confirm-apply/scripts/provider-path.sh"
  for rel in plugins/plugin-editor plugins/template-editor plugins/scaffold-retarget; do
    run diff "$canonical" "$(repo_root_dir)/$rel/scripts/provider-path.sh"
    [ "$status" -eq 0 ]
  done
}

@test "usage: no provider name" {
  run "$PP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"usage:"* ]]
}

@test "usage: provider but no required files" {
  run "$PP" plan-kit
  [ "$status" -ne 0 ]
  [[ "$output" == *"at least one required file"* ]]
}

@test "an unknown option is rejected" {
  run "$PP" plan-kit validate-plan.sh --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "exits non-zero and names the provider + env var when not found" {
  # The resolver also searches up from its OWN location, so the real in-repo copy always
  # finds the real providers. Run a COPY from an isolated dir with no provider ancestor.
  command -v validate-plan.sh >/dev/null 2>&1 && skip "validate-plan.sh is on PATH"
  local iso
  iso="$(mktemp -d)"
  local d="$iso"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/plugins/plan-kit/scripts" ]] && skip "an ancestor of the scratch dir holds plan-kit"
    d="$(dirname "$d")"
  done
  cp "$PP" "$iso/provider-path.sh"
  run bash "$iso/provider-path.sh" plan-kit validate-plan.sh --from "$iso"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plan-kit not found"* ]]
  [[ "$output" == *"PLAN_KIT_DIR"* ]]
}

@test "the partial-toolkit guard rejects an incomplete edit-kit (isolated)" {
  command -v check-structure.sh >/dev/null 2>&1 && skip "check-structure.sh is on PATH"
  local iso
  iso="$(mktemp -d)"
  local d="$iso"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/plugins/edit-kit/scripts" ]] && skip "an ancestor of the scratch dir holds edit-kit"
    d="$(dirname "$d")"
  done
  cp "$PP" "$iso/provider-path.sh"
  # Only check-structure.sh present, not the rest.
  write_files "$iso/plugins/edit-kit/scripts" check-structure.sh
  # shellcheck disable=SC2086
  run bash "$iso/provider-path.sh" edit-kit $EDIT_KIT_FILES --from "$iso"
  [ "$status" -ne 0 ]
  [[ "$output" == *"edit-kit not found"* ]]
}
