#!/usr/bin/env bash
# validate-plan.sh — the shared plan-shape gate for the plan-confirm-apply archetype.
#
# A plan-confirm-apply command delegates to a read-only planner subagent that returns a
# JSON plan; this script is the deterministic gate the command runs on that plan before
# presenting or acting on it. It checks only the shape every plan-confirm-apply plan
# shares — summary / actions[] / questions[] — and validates each action's verb against a
# caller-supplied vocabulary, so a consumer whose plans use a different action set (e.g.
# add/keep/update/delete) validates correctly without forking this script.
#
# Usage: validate-plan.sh [--actions a,b,c] [plan-file]
#   --actions   comma-separated allowed values for each actions[].action
#               (default: create,modify,delete)
#   plan-file   read the plan JSON from this file (default: stdin)
#
# Exits 0 when the plan is valid. Exits 1 with a message on stderr naming the first
# violation found (malformed JSON, a missing/mistyped field, or an illegal action).
set -euo pipefail

die() {
  printf 'validate-plan: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

allowed="create,modify,delete"
plan_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --actions)
      [[ $# -ge 2 ]] || die "--actions needs a value"
      allowed="$2"
      shift 2
      ;;
    --actions=*)
      allowed="${1#--actions=}"
      shift
      ;;
    -h | --help)
      grep -E '^# ' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --)
      shift
      [[ $# -gt 0 ]] && plan_file="$1"
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      plan_file="$1"
      shift
      ;;
  esac
done

# CSV vocabulary -> a JSON array (trimmed, empties dropped) for jq.
allowed_json="$(printf '%s' "$allowed" |
  jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length > 0))')"
[[ "$(jq 'length' <<<"$allowed_json")" -gt 0 ]] || die "--actions must list at least one action"

if [[ -n "$plan_file" ]]; then
  [[ -f "$plan_file" ]] || die "no such file: $plan_file"
  plan_json="$(cat "$plan_file")"
else
  plan_json="$(cat)"
fi

# Malformed JSON is checked separately so its message is a parse error, not a shape
# violation.
parse_err="$(jq empty <<<"$plan_json" 2>&1)" && parse_rc=0 || parse_rc=$?
[[ "$parse_rc" -eq 0 ]] || die "malformed JSON: ${parse_err}"

# One jq program walks the shape in order and halts on the first violation (via
# halt_error, which prints the bare message with no "jq: error" wrapping), so the caller
# always names a single, specific problem. Each action verb is bound to $a BEFORE piping
# into $allowed, so the vocabulary array can't shadow the entry being tested.
violation="$(jq -n --argjson plan "$plan_json" --argjson allowed "$allowed_json" '
  $plan as $p
  | if ($p | type) != "object" then
      "plan must be a JSON object" | halt_error(1)
    elif ($p.summary | type) != "string" then
      "summary must be a string" | halt_error(1)
    elif ($p.actions | type) != "array" then
      "actions must be an array" | halt_error(1)
    elif ($p.questions | type) != "array" then
      "questions must be an array" | halt_error(1)
    else
      ( $p.actions | to_entries[] |
        if (.value | type) != "object" then
          "actions[\(.key)] must be an object" | halt_error(1)
        elif (.value.path | type) != "string" then
          "actions[\(.key)].path must be a string" | halt_error(1)
        elif (.value.action as $a | $allowed | index($a)) == null then
          "actions[\(.key)].action must be one of: \($allowed | join(", "))"
          | halt_error(1)
        else empty
        end
      )
    end
' 2>&1 1>/dev/null)" && violation_rc=0 || violation_rc=$?

[[ "$violation_rc" -eq 0 ]] || die "$violation"

exit 0
