#!/usr/bin/env bats
#
# Tests for templates/plan-confirm-apply/scripts/plan-kit-path.sh — resolves the plan-kit
# provider's scripts directory ($PLAN_KIT_DIR -> marketplace ancestor -> PATH) so the
# scaffolded guided command never vendors validate-plan.sh. A candidate dir must actually
# hold the toolkit (validate-plan.sh), not merely exist. Centralized so CI's
# `bats scripts/tests` gates the resolver the template ships to every consumer.

load helpers

# Write a stub plan-kit toolkit into <dir>.
write_kit() {
  local dir="$1"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/validate-plan.sh"
}

setup() {
  # A PLAN_KIT_DIR in the runner env would win the resolver's override tier and defeat
  # the ancestor/not-found assertions below — make the tests hermetic.
  unset PLAN_KIT_DIR
  PKP="$(repo_root_dir)/templates/plan-confirm-apply/scripts/plan-kit-path.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/sub/deep"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  write_kit "$FIX/plugins/plan-kit/scripts"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "resolves plan-kit via the marketplace ancestor" {
  run "$PKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ]
}

@test "resolves from a deep subdirectory" {
  run "$PKP" "$FIX/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ]
}

@test "honors a valid PLAN_KIT_DIR override" {
  local other
  other="$(mktemp -d)"
  write_kit "$other"
  PLAN_KIT_DIR="$other" run "$PKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$other" ]
  rm -rf "$other"
}

@test "a PLAN_KIT_DIR missing validate-plan.sh falls through to the ancestor" {
  local partial
  partial="$(mktemp -d)" # empty -> no validate-plan.sh
  PLAN_KIT_DIR="$partial" run "$PKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ] # partial rejected -> real ancestor
  rm -rf "$partial"
}

@test "exits non-zero with a hint when plan-kit is not found" {
  # The resolver also searches up from its OWN location, so the real in-repo script
  # always finds the real plan-kit. Run a COPY from an isolated dir so neither the
  # start-dir nor the script's own SCRIPT_DIR anchor has a plan-kit ancestor.
  command -v validate-plan.sh >/dev/null 2>&1 && skip "validate-plan.sh is on PATH"
  local iso
  iso="$(mktemp -d)"
  local d="$iso"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/plugins/plan-kit/scripts" ]] && skip "an ancestor of the scratch dir holds plan-kit"
    d="$(dirname "$d")"
  done
  cp "$PKP" "$iso/plan-kit-path.sh"
  run bash "$iso/plan-kit-path.sh" "$iso"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plan-kit not found"* ]]
  rm -rf "$iso"
}
