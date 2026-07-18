#!/usr/bin/env bats
#
# Tests for plan-kit/scripts/validate-plan.sh — the shared plan-shape gate for the
# plan-confirm-apply archetype. The script checks the shape every plan-confirm-apply plan
# shares (summary / actions[] / questions[]) and validates each action verb against a
# caller-supplied --actions vocabulary. These pin that contract, including the vocabulary
# parameterization (a consumer using add/keep/update/delete must validate correctly) and
# the two easy-to-miss cases: tolerating domain-specific extra fields and reporting the
# correct offending action index. Centralized (not bundled) so CI's `bats scripts/tests`
# gates it, matching edit-kit.

load helpers

setup() {
  SCRIPT="$(repo_root_dir)/plugins/plan-kit/scripts/validate-plan.sh"
}

# --- valid plans (default vocabulary: create/modify/delete) -----------------

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

# --- vocabulary parameterization (--actions) --------------------------------

@test "default vocabulary rejects an out-of-set verb like 'add'" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":"add"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be one of: create, modify, delete"* ]]
}

@test "--actions accepts a consumer's own vocabulary" {
  run "$SCRIPT" --actions add,keep,update,delete <<<'{"summary":"x","actions":[{"path":"a","action":"add"},{"path":"b","action":"keep"},{"path":"c","action":"update"}],"questions":[]}'
  [ "$status" -eq 0 ]
}

@test "--actions makes the default verbs illegal (vocabulary is exclusive)" {
  run "$SCRIPT" --actions add,keep,update,delete <<<'{"summary":"x","actions":[{"path":"a","action":"create"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be one of: add, keep, update, delete"* ]]
}

@test "--actions=VALUE form is accepted" {
  run "$SCRIPT" --actions=add,keep <<<'{"summary":"x","actions":[{"path":"a","action":"keep"}],"questions":[]}'
  [ "$status" -eq 0 ]
}

@test "--actions tolerates spaces around verbs" {
  run "$SCRIPT" --actions "add, keep, update, delete" <<<'{"summary":"x","actions":[{"path":"a","action":"update"}],"questions":[]}'
  [ "$status" -eq 0 ]
}

@test "an empty --actions set is rejected" {
  run "$SCRIPT" --actions "" <<<'{"summary":"x","actions":[],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--actions must list at least one action"* ]]
}

@test "an unknown option is rejected" {
  run "$SCRIPT" --bogus <<<'{}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

# --- array-field parameterization (--field) ---------------------------------

@test "--field validates a differently-named change array (files)" {
  run "$SCRIPT" --field files <<<'{"summary":"s","changeType":"add","files":[{"path":"commands/x.md","action":"create","edit":"why"},{"path":"y.md","action":"modify"}],"changelog":{"category":"Added"},"bumpLevel":"minor","questions":[]}'
  [ "$status" -eq 0 ]
}

@test "--field=VALUE form is accepted" {
  run "$SCRIPT" --field=files <<<'{"summary":"s","files":[],"questions":[]}'
  [ "$status" -eq 0 ]
}

@test "--field reports violations under the configured name" {
  run "$SCRIPT" --field files <<<'{"summary":"s","files":[{"path":"a","action":"create"},{"path":"b","action":"rename"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'files[1].action must be one of'* ]]
}

@test "--field: a missing configured array is reported by its name" {
  run "$SCRIPT" --field files <<<'{"summary":"s","actions":[],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"files must be an array"* ]]
}

@test "--field: array-valued action is still rejected (no bypass)" {
  run "$SCRIPT" --field files <<<'{"summary":"s","files":[{"path":"a","action":["create"]}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'files[0].action must be one of'* ]]
}

@test "--field combines with --actions" {
  run "$SCRIPT" --field files --actions add,keep,update,delete <<<'{"summary":"s","files":[{"path":"a","action":"keep"}],"questions":[]}'
  [ "$status" -eq 0 ]
}

@test "an empty --field is rejected" {
  run "$SCRIPT" --field "" <<<'{"summary":"s","actions":[],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--field must be a non-empty name"* ]]
}

@test "the default field remains 'actions' (a files-only plan is rejected)" {
  run "$SCRIPT" <<<'{"summary":"s","files":[{"path":"a","action":"create"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"actions must be an array"* ]]
}

# --- top-level shape violations --------------------------------------------

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

# --- per-action violations (with correct index) ----------------------------

@test "treats a missing action as illegal" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].action must be one of'* ]]
}

@test "reports the offending action index (second item)" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":"create"},{"path":"b","action":"nope"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[1].action must be one of'* ]]
}

@test "rejects an action with a non-string path" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"action":"create"}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].path must be a string'* ]]
}

@test "rejects an array-valued action (index() subsequence-match must not slip through)" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":["create","modify"]}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].action must be one of'* ]]
}

@test "rejects a non-string scalar action (number)" {
  run "$SCRIPT" <<<'{"summary":"x","actions":[{"path":"a","action":5}],"questions":[]}'
  [ "$status" -ne 0 ]
  [[ "$output" == *'actions[0].action must be one of'* ]]
}

# --- input handling --------------------------------------------------------

@test "reports malformed JSON as a parse error, not a shape violation" {
  run "$SCRIPT" <<<'{not json'
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed JSON"* ]]
}

@test "reports empty input as malformed JSON, not a raw jq usage dump" {
  run bash -c 'printf "" | "$1"' _ "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed JSON"* ]]
  [[ "$output" != *"Use jq --help"* ]]
}

@test "reports whitespace-only input as malformed JSON" {
  run bash -c 'printf "  \n " | "$1"' _ "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed JSON"* ]]
}

@test "rejects a multi-document JSON stream as malformed" {
  run "$SCRIPT" <<<'{}{}'
  [ "$status" -ne 0 ]
  [[ "$output" == *"malformed JSON"* ]]
}

@test "reads a plan from a file argument" {
  printf '%s' '{"summary":"x","actions":[],"questions":[]}' >"$BATS_TEST_TMPDIR/plan.json"
  run "$SCRIPT" "$BATS_TEST_TMPDIR/plan.json"
  [ "$status" -eq 0 ]
}

@test "combines --actions with a file argument" {
  printf '%s' '{"summary":"x","actions":[{"path":"a","action":"keep"}],"questions":[]}' >"$BATS_TEST_TMPDIR/plan.json"
  run "$SCRIPT" --actions add,keep,update,delete "$BATS_TEST_TMPDIR/plan.json"
  [ "$status" -eq 0 ]
}

@test "errors when the file argument does not exist" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/nope.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no such file"* ]]
}
