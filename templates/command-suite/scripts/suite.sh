#!/usr/bin/env bash
# suite.sh — the single deterministic backend for a command-suite plugin. It
# demonstrates the "command suite" archetype: several thin slash commands that
# all dispatch into one mechanized script (a subcommand each), so no model tokens
# are spent on work a script can do for free.
#
# Usage: suite.sh <upper|count> [text...]
set -euo pipefail

usage() { printf 'usage: suite.sh <upper|count> [text...]\n' >&2; }

sub="${1:-}"
[[ -n "$sub" ]] || {
  usage
  exit 1
}
shift
text="$*"

case "$sub" in
  upper) printf '%s\n' "${text^^}" ;;
  count) printf '%s\n' "$(printf '%s' "$text" | wc -w | tr -d ' ')" ;;
  *)
    usage
    exit 1
    ;;
esac
