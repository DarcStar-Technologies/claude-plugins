#!/usr/bin/env bats
#
# Tests for template-editor/scripts/discover-templates.sh — the picker discovery
# step. Builds a throwaway marketplace fixture with a stub list-templates.sh so the
# real repo is untouched.

load helpers

setup() {
  DT="$(repo_root_dir)/plugins/template-editor/scripts/discover-templates.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/scripts" "$FIX/templates/alpha" "$FIX/templates/beta" "$FIX/sub"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  cat >"$FIX/scripts/list-templates.sh" <<'SH'
#!/usr/bin/env bash
[[ "${1:-}" == "--json" ]] && printf '[{"name":"alpha","version":"0.1.0","description":"Alpha."},{"name":"beta","version":"0.2.0","description":"Beta."}]\n'
SH
  chmod +x "$FIX/scripts/list-templates.sh"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "lists templates under templates/ with absolute paths" {
  run "$DT" "$FIX"
  [ "$status" -eq 0 ]
  # Parse with jq so the assertions don't depend on JSON formatting.
  names="$(printf '%s' "$output" | jq -r '[.[].name] | join(",")')"
  [ "$names" = "alpha,beta" ]
  paths="$(printf '%s' "$output" | jq -r '.[].path')"
  [[ "$paths" == *"/templates/alpha"* ]]
  [[ "$paths" == *"/templates/beta"* ]]
  [ "$(printf '%s' "$output" | jq -r '.[1].description')" = "Beta." ]
}

@test "finds the marketplace from a subdirectory" {
  run "$DT" "$FIX/sub"
  [ "$status" -eq 0 ]
  [[ "$output" == *'/templates/alpha"'* ]]
}

@test "exits 2 with no output when no marketplace ancestor is found" {
  local solo
  solo="$(mktemp -d)"
  # Hermeticity guard: skip if the scratch dir happens to sit under a real
  # marketplace (e.g. TMPDIR inside a checkout), which would give a valid listing.
  local d="$solo"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/.claude-plugin/marketplace.json" ]] && skip "scratch dir has a marketplace ancestor"
    d="$(dirname "$d")"
  done
  run "$DT" "$solo"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  rm -rf "$solo"
}

@test "prints [] when the marketplace has no list-templates.sh" {
  rm "$FIX/scripts/list-templates.sh"
  run "$DT" "$FIX"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}
