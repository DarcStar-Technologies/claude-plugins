#!/usr/bin/env bats
#
# Tests for template-editor/scripts/edit-kit-path.sh — resolves the edit-kit
# toolkit's scripts directory ($EDIT_KIT_DIR -> marketplace ancestor -> PATH). A
# candidate dir must hold the WHOLE toolkit, not just the sentinel.

load helpers

# The full set edit-kit-path.sh requires a candidate dir to contain.
EK_SCRIPTS="check-structure.sh update-changelog.sh sync-version.sh scaffold-test.sh verify-repo.sh"

# Write a complete stub toolkit into <dir>.
write_kit() {
  local dir="$1" s
  mkdir -p "$dir"
  for s in $EK_SCRIPTS; do printf '#!/usr/bin/env bash\ntrue\n' >"$dir/$s"; done
}

setup() {
  EKP="$(repo_root_dir)/plugins/template-editor/scripts/edit-kit-path.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/sub/deep"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  write_kit "$FIX/plugins/edit-kit/scripts"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "resolves edit-kit via the marketplace ancestor" {
  run "$EKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/edit-kit/scripts" ]
}

@test "resolves from a deep subdirectory" {
  run "$EKP" "$FIX/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/edit-kit/scripts" ]
}

@test "honors a valid EDIT_KIT_DIR override" {
  local other
  other="$(mktemp -d)"
  write_kit "$other"
  EDIT_KIT_DIR="$other" run "$EKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$other" ]
  rm -rf "$other"
}

@test "an EDIT_KIT_DIR missing scripts falls through to the ancestor" {
  local partial
  partial="$(mktemp -d)"
  printf '#!/usr/bin/env bash\ntrue\n' >"$partial/check-structure.sh" # only the sentinel
  EDIT_KIT_DIR="$partial" run "$EKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/edit-kit/scripts" ] # partial rejected -> real ancestor
  rm -rf "$partial"
}

@test "exits non-zero with a hint when edit-kit is not found" {
  # The resolver also searches up from its OWN location, so the real script always
  # finds the real edit-kit in-repo. Run a COPY from an isolated dir so neither the
  # start-dir nor the script's own SCRIPT_DIR anchor has an edit-kit ancestor.
  command -v check-structure.sh >/dev/null 2>&1 && skip "check-structure.sh is on PATH"
  local iso
  iso="$(mktemp -d)"
  local d="$iso"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/plugins/edit-kit/scripts" ]] && skip "an ancestor of the scratch dir holds edit-kit"
    d="$(dirname "$d")"
  done
  cp "$EKP" "$iso/edit-kit-path.sh"
  run bash "$iso/edit-kit-path.sh" "$iso"
  [ "$status" -ne 0 ]
  [[ "$output" == *"edit-kit not found"* ]]
  rm -rf "$iso"
}
