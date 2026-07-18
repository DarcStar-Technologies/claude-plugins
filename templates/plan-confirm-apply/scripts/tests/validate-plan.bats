#!/usr/bin/env bats
#
# Tests for scripts/validate-plan.sh — the plan-confirm-apply archetype's deterministic
# gate on the {{NAME}}-planner agent's JSON plan. The script checks only the shape every
# plan-confirm-apply plan shares (summary / actions[] / questions[]) and names the first
# violation it finds; these tests pin that contract, including the two easy-to-miss cases:
# it must tolerate domain-specific extra fields (risks[], per-action detail) and it must
# report the correct offending action index.

setup() {
  # The script under test is a sibling one level up, in <plugin>/scripts/.
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/validate-plan.sh"
}

# --- valid plans -----------------------------------------------------------

@test "accepts a valid plan with create/modify/delete actions" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":"create"},{"path":"b","action":"modify"},{"path":"c","action":"delete"}],"questions":[]}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "accepts a valid plan with empty actions and a question" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[],"questions":["which file?"]}'
  [ "$status" -eq 0 ]
}

@test "tolerates domain-specific extra fields (risks[], per-action detail)" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":"create","detail":"why"}],"risks":["blast radius"],"questions":[]}'
  [ "$status" -eq 0 ]
}

# --- top-level shape violations -------------------------------------------

@test "rejects a missing summary" {
  run "$SCRIPT" <<<'{"actions":[],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"summary must be a string"* ]]
}

@test "rejects a non-string summary" {
  run "$SCRIPT" <<<'{"summary":5,"actions":[],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"summary must be a string"* ]]
}

@test "rejects a non-array actions" {
  run "$SCRIPT" <<<'{"summary":"x","actions":{},"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"actions must be an array"* ]]
}

@test "rejects a non-array questions" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[],"questions":"no"}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"questions must be an array"* ]]
}

# --- per-action violations (with correct index) ---------------------------

@test "rejects an illegal action value" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":"rename"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].action must be'* ]]
}

@test "treats a missing action as illegal" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].action must be'* ]]
}

@test "reports the offending action index (second item)" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":"create"},{"path":"b","action":"nope"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[1].action must be'* ]]
}

@test "rejects an action with a non-string path" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"action":"create"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].path must be a string'* ]]
}

# --- input handling --------------------------------------------------------

@test "reports malformed JSON as a parse error, not a shape violation" {
  run "$SCRIPT" <<<'{not json'
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed JSON"* ]]
}

@test "reads a plan from a file argument" {
  printf '%s' '{"summary":"x","actions":[],"questions":[]}' >"$BATS_TEST_TMPDIR/plan.json"
  run "$SCRIPT" "$BATS_TEST_TMPDIR/plan.json"
  [ "$status" -eq 0 ]
}

@test "errors when the file argument does not exist" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/nope.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no such file"* ]]
}
