#!/usr/bin/env bats
#
# Tests for template-editor/scripts/edit-kit-path.sh — resolves the edit-kit
# toolkit's scripts directory ($EDIT_KIT_DIR -> marketplace ancestor -> PATH).

load helpers

setup() {
  EKP="$(repo_root_dir)/plugins/template-editor/scripts/edit-kit-path.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/plugins/edit-kit/scripts" "$FIX/sub/deep"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  # The sentinel edit-kit-path.sh looks for.
  printf '#!/usr/bin/env bash\ntrue\n' >"$FIX/plugins/edit-kit/scripts/check-structure.sh"
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
  printf '#!/usr/bin/env bash\ntrue\n' >"$other/check-structure.sh"
  EDIT_KIT_DIR="$other" run "$EKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$other" ]
  rm -rf "$other"
}

@test "an invalid EDIT_KIT_DIR falls through to the ancestor" {
  EDIT_KIT_DIR=/nonexistent-xyz run "$EKP" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/edit-kit/scripts" ]
}

@test "exits non-zero with a hint when edit-kit is not found" {
  local solo
  solo="$(mktemp -d)"
  run "$EKP" "$solo"
  [ "$status" -ne 0 ]
  [[ "$output" == *"edit-kit not found"* ]]
  rm -rf "$solo"
}
