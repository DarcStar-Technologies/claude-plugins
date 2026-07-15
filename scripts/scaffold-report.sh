#!/usr/bin/env bash
# Report the template provenance of every published plugin and flag drift where
# the source template has advanced past the version a plugin was scaffolded
# from.
#
#   scaffold-report.sh            informational; always exits 0
#   scaffold-report.sh --strict   exits non-zero on MAJOR-version drift that is
#                                 not listed in .scaffold-exceptions.json
#
# Minor/patch drift is always informational. The exception list is a map of
# `plugin-name -> reason` in .scaffold-exceptions.json at the repo root; a plugin
# listed there may lag a major template version without failing --strict.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_cmd jq

strict=0
[[ "${1:-}" == "--strict" ]] && strict=1

root="$(repo_root)"
exceptions_file="$root/.scaffold-exceptions.json"
if [[ -f "$exceptions_file" ]]; then
  jq empty "$exceptions_file" 2>/dev/null ||
    die ".scaffold-exceptions.json is not valid JSON"
fi

# reason_for <plugin> -> the exception reason, or empty if the plugin is not
# on the exception list.
reason_for() {
  [[ -f "$exceptions_file" ]] || return 0
  jq -r --arg n "$1" '.exceptions[$n] // empty' "$exceptions_file"
}

# major <semver> -> the major component, or "-" when it is not a plain integer.
major() {
  local m="${1%%.*}"
  if [[ "$m" =~ ^[0-9]+$ ]]; then
    printf '%s' "$m"
  else
    printf '%s' "-"
  fi
}

fmt='%-24s %-12s %-9s %-8s %s\n'
# shellcheck disable=SC2059
printf "$fmt" PLUGIN TEMPLATE SCAFFOLD CURRENT STATUS
# shellcheck disable=SC2059
printf "$fmt" ------ -------- -------- ------- ------

blocking=0
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  name="$(basename "$dir")"
  scaffold="$dir/.claude-plugin/scaffold.json"

  if [[ ! -f "$scaffold" ]]; then
    # shellcheck disable=SC2059
    printf "$fmt" "$name" "-" "-" "-" "no-provenance"
    continue
  fi

  tmpl="$(jq -r '.template // "-"' "$scaffold")"
  tver="$(jq -r '.templateVersion // "-"' "$scaffold")"

  current="-"
  tmanifest="$root/plugins/$tmpl/.claude-plugin/plugin.json"
  [[ -f "$tmanifest" ]] && current="$(jq -r '.version // "-"' "$tmanifest")"

  status="ok"
  if [[ "$current" == "-" ]]; then
    status="template-gone"
  elif [[ "$tver" != "$current" ]]; then
    rec_major="$(major "$tver")"
    cur_major="$(major "$current")"
    if [[ "$rec_major" != "-" && "$cur_major" != "-" && "$cur_major" -gt "$rec_major" ]]; then
      if [[ -n "$(reason_for "$name")" ]]; then
        status="MAJOR-DRIFT(allowed)"
      else
        status="MAJOR-DRIFT"
        blocking=1
      fi
    else
      status="DRIFT"
    fi
  fi

  # shellcheck disable=SC2059
  printf "$fmt" "$name" "$tmpl" "$tver" "$current" "$status"
done < <(list_plugin_dirs public)

# Hygiene: warn about exception entries that reference plugins that don't exist.
if [[ -f "$exceptions_file" ]]; then
  while IFS= read -r ex; do
    [[ -n "$ex" ]] || continue
    [[ -d "$root/plugins/$ex" ]] ||
      warn "exception for unknown plugin '$ex' in .scaffold-exceptions.json"
  done < <(jq -r '.exceptions | keys[]?' "$exceptions_file")
fi

if [[ "$blocking" -eq 1 ]]; then
  if [[ "$strict" -eq 1 ]]; then
    die "major template drift on a plugin not in .scaffold-exceptions.json — update the plugin or add an exception with a reason"
  fi
  warn "major template drift detected (would fail under --strict)"
fi
