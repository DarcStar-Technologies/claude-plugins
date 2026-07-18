#!/usr/bin/env bash
# validate-plan.sh — the VALIDATION step of the plan-confirm-apply archetype.
# The {{NAME}}-planner agent returns a JSON plan in the command's step 3; this
# script is the deterministic gate the {{NAME}} command runs on that plan
# immediately afterward, before presenting or acting on it in any later step
# (unknowns / confirm / apply). It checks only the shape every
# plan-confirm-apply plan shares — summary / actions[] / questions[] — never a
# domain-specific field (e.g. risks[]) a scaffolded plugin's planner adds; no
# adaptation is needed after scaffolding.
#
# Usage: validate-plan.sh [plan-file]   (default: read JSON from stdin)
#
# Exits 0 when the plan is valid. Exits 1 with a message on stderr naming the
# first violation found (malformed JSON, a missing/mistyped field, or an
# illegal `action` value) when invalid.
set -euo pipefail

die() {
  printf 'validate-plan: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

plan_file="${1:-}"
if [[ -n "$plan_file" ]]; then
  [[ -f "$plan_file" ]] || die "no such file: $plan_file"
  plan_json="$(cat "$plan_file")"
else
  plan_json="$(cat)"
fi

# Malformed JSON is checked separately so its message is a parse error, not a
# shape violation.
parse_err="$(jq empty <<<"$plan_json" 2>&1)" && parse_rc=0 || parse_rc=$?
[[ "$parse_rc" -eq 0 ]] || die "malformed JSON: ${parse_err}"

# One jq program walks the shape in order and halts on the first violation (via
# halt_error, which prints the bare message with no "jq: error" wrapping), so
# the caller always names a single, specific problem.
violation="$(jq -n --argjson plan "$plan_json" '
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
        elif (.value.action as $a | ["create", "modify", "delete"] | index($a)) == null then
          "actions[\(.key)].action must be \"create\", \"modify\", or \"delete\""
          | halt_error(1)
        else empty
        end
      )
    end
' 2>&1 1>/dev/null)" && violation_rc=0 || violation_rc=$?

[[ "$violation_rc" -eq 0 ]] || die "$violation"

exit 0
