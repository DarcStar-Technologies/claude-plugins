#!/usr/bin/env bats
#
# Tests for template-editor's bundled plan-kit resolver and the plan-kit integration
# contract. The edit-template command validates the planner's JSON plan via the shared
# plan-kit provider; this planner names its change array files[] (not the archetype's
# actions[]), so the command wires validate-plan.sh --field files.

load helpers

setup() {
  # A PLAN_KIT_DIR in the runner env would win the resolver's override tier — keep hermetic.
  unset PLAN_KIT_DIR
  PKP="$(repo_root_dir)/plugins/template-editor/scripts/plan-kit-path.sh"
  VP="$(repo_root_dir)/plugins/plan-kit/scripts/validate-plan.sh"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/.claude-plugin" "$FIX/sub/deep" "$FIX/plugins/plan-kit/scripts"
  printf '{"name":"t","owner":{"name":"t"},"plugins":[]}\n' >"$FIX/.claude-plugin/marketplace.json"
  printf '#!/usr/bin/env bash\ntrue\n' >"$FIX/plugins/plan-kit/scripts/validate-plan.sh"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "plan-kit-path.sh resolves the plan-kit provider via a marketplace ancestor" {
  run "$PKP" "$FIX/sub/deep"
  [ "$status" -eq 0 ]
  [ "$output" = "$FIX/plugins/plan-kit/scripts" ]
}

@test "the planner's files[] vocabulary validates via plan-kit --field files" {
  # template-edit-planner returns files[] items with create/modify/delete actions.
  local plan='{"summary":"s","changeType":"add","files":[{"path":"commands/x.md","action":"create","edit":"why"},{"path":"y.md","action":"modify","edit":"z"}],"changelog":{"category":"Added","bullet":"b"},"bumpLevel":"minor","risks":[],"questions":[]}'
  run bash -c 'printf "%s" "$2" | "$1" --field files --actions create,modify,delete' _ "$VP" "$plan"
  [ "$status" -eq 0 ]
  # Without --field, the default actions[] check rejects this files-shaped plan — proving
  # the --field wiring is required, not incidental.
  run bash -c 'printf "%s" "$2" | "$1"' _ "$VP" "$plan"
  [ "$status" -ne 0 ]
  [[ "$output" == *"actions must be an array"* ]]
}
