#!/usr/bin/env bash
# common.sh — shared helpers for scaffold-retarget's scripts. Sourced, not executed.

# sr_render <content> <name> <desc> — substitute a template's {{NAME}}/{{DESC}} with the
# plugin's own identity, the same way the scaffolder does (including the trailing newline).
#
# {{DESC}} is filled by consuming the ORIGINAL string segment-by-segment and accumulating
# into `out`, so a description that itself contains the literal "{{DESC}}" can NOT
# reintroduce the token and spin forever. Concatenation is literal, so a `&` in the
# description can't be mangled by bash 5.2 patsub_replacement either. {{NAME}} is a
# validated kebab plugin name (no `{{`, no `&`), so plain // is safe for it.
sr_render() {
  local c="$1" name="$2" desc="$3" out="" rest
  c="${c//\{\{NAME\}\}/$name}"
  rest="$c"
  while [[ "$rest" == *'{{DESC}}'* ]]; do
    out+="${rest%%\{\{DESC\}\}*}$desc"
    rest="${rest#*\{\{DESC\}\}}"
  done
  out+="$rest"
  printf '%s\n' "$out"
}
