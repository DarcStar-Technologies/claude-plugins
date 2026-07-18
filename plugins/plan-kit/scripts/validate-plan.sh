#!/usr/bin/env bash
# validate-plan.sh — the shared plan-shape gate for the plan-confirm-apply archetype.
#
# A plan-confirm-apply command delegates to a read-only planner subagent that returns a
# JSON plan; this script is the deterministic gate the command runs on that plan before
# presenting or acting on it. It checks only the shape every plan-confirm-apply plan
# shares — summary / <field>[] / questions[], where <field> is the array of change items
# (default `actions`; --field names it, e.g. `files`) — and validates each item's verb
# against a caller-supplied vocabulary (--actions), so a consumer whose plans use a
# different array name or action set validates without forking this script.
#
# Usage: validate-plan.sh [--field name] [--actions a,b,c] [plan-file]
#   --field     the top-level array of change items to validate (default: actions).
#               A consumer whose planner names it differently (e.g. files) passes it.
#   --actions   comma-separated allowed values for each <field>[].action
#               (default: create,modify,delete)
#   plan-file   read the plan JSON from this file (default: stdin); pass `--` before a
#               plan-file path that begins with a dash
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
field="actions"
plan_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --field)
      [[ $# -ge 2 ]] || die "--field needs a value"
      field="$2"
      shift 2
      ;;
    --field=*)
      field="${1#--field=}"
      shift
      ;;
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
[[ -n "$field" ]] || die "--field must be a non-empty name"
# summary/questions are validated by their own fixed checks below; selecting either as the
# change array is self-contradictory (it can never validate any plan), so reject it up front.
case "$field" in
  summary | questions)
    die "--field cannot be '$field' — that name is reserved for the plan's own fields"
    ;;
esac

if [[ -n "$plan_file" ]]; then
  [[ -f "$plan_file" ]] || die "no such file: $plan_file"
  plan_json="$(cat "$plan_file")"
else
  plan_json="$(cat)"
fi

# The plan must be exactly ONE well-formed JSON value before it reaches --argjson below,
# which otherwise rejects empty, whitespace-only, or multi-document input with a cryptic
# jq usage dump. `jq empty` accepts zero or many documents, so count them explicitly and
# give every bad-input case the same clean "malformed JSON" message.
ndocs="$(jq -n 'reduce inputs as $x (0; . + 1)' <<<"$plan_json" 2>&1)" && count_rc=0 || count_rc=$?
[[ "$count_rc" -eq 0 ]] || die "malformed JSON: ${ndocs}"
[[ "$ndocs" == "1" ]] || die "malformed JSON: expected exactly one JSON value, got ${ndocs}"

# One jq program walks the shape in order and halts on the first violation (via
# halt_error, which prints the bare message with no "jq: error" wrapping), so the caller
# always names a single, specific problem. Action membership is tested with an equality
# fold over $allowed — NOT index($a), whose array-argument subsequence matching would let
# a non-string action like ["create","modify"] slip past the vocabulary gate.
violation="$(jq -n --argjson plan "$plan_json" --argjson allowed "$allowed_json" --arg field "$field" '
  $plan as $p
  | if ($p | type) != "object" then
      "plan must be a JSON object" | halt_error(1)
    elif ($p.summary | type) != "string" then
      "summary must be a string" | halt_error(1)
    elif ($p[$field] | type) != "array" then
      "\($field) must be an array" | halt_error(1)
    elif ($p.questions | type) != "array" then
      "questions must be an array" | halt_error(1)
    else
      ( $p[$field] | to_entries[] |
        if (.value | type) != "object" then
          "\($field)[\(.key)] must be an object" | halt_error(1)
        elif (.value.path | type) != "string" then
          "\($field)[\(.key)].path must be a string" | halt_error(1)
        elif ([$allowed[] == .value.action] | any | not) then
          "\($field)[\(.key)].action must be one of: \($allowed | join(", "))"
          | halt_error(1)
        else empty
        end
      )
    end
' 2>&1 1>/dev/null)" && violation_rc=0 || violation_rc=$?

[[ "$violation_rc" -eq 0 ]] || die "$violation"

exit 0
