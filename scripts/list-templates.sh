#!/usr/bin/env bash
# List the reference templates the scaffolder can build from: the plugins under
# templates/ (a sibling of plugins/). Each is a fully valid plugin whose component
# directories (commands/agents/skills/scripts) plugin-forge copies into a new
# plugin.
#
#   list-templates.sh          human-readable table (NAME  VERSION  DESCRIPTION)
#   list-templates.sh --json   JSON array of {name, version, description} for
#                              tooling (e.g. plugin-forge)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_cmd jq

json=0
[[ "${1:-}" == "--json" ]] && json=1

# Gather each template's name (directory), version, and description from its
# plugin.json. A template without a manifest is skipped with a warning.
names=()
versions=()
descs=()
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  manifest="$dir/.claude-plugin/plugin.json"
  if [[ ! -f "$manifest" ]]; then
    warn "$(basename "$dir"): no plugin.json; skipping"
    continue
  fi
  names+=("$(jq -r '.name // empty' "$manifest")")
  versions+=("$(jq -r '.version // "-"' "$manifest")")
  descs+=("$(jq -r '.description // ""' "$manifest")")
done < <(list_plugin_dirs templates)

if [[ "$json" -eq 1 ]]; then
  # Emit a JSON array built from the parallel arrays.
  out='[]'
  for i in "${!names[@]}"; do
    out="$(jq --arg n "${names[$i]}" --arg v "${versions[$i]}" --arg d "${descs[$i]}" \
      '. += [{name: $n, version: $v, description: $d}]' <<<"$out")"
  done
  printf '%s\n' "$out"
  exit 0
fi

if [[ "${#names[@]}" -eq 0 ]]; then
  info "no templates found under templates/ (expected reference plugins there)"
  exit 0
fi

fmt='%-18s %-9s %s\n'
# shellcheck disable=SC2059
printf "$fmt" NAME VERSION DESCRIPTION
# shellcheck disable=SC2059
printf "$fmt" ---- ------- -----------
for i in "${!names[@]}"; do
  # shellcheck disable=SC2059
  printf "$fmt" "${names[$i]}" "${versions[$i]}" "${descs[$i]}"
done
