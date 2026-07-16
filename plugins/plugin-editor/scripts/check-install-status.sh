#!/usr/bin/env bash
# check-install-status.sh — is this plugin installed (active) in the current
# Claude Code session, and does it need a reload after edits?
#
# Reads ~/.claude/plugins/installed_plugins.json (override the path with
# $INSTALLED_PLUGINS_JSON for tests), matches install records keyed
# "<name>@<marketplace>" (scoped to the plugin's own marketplace when derivable,
# else any "<name>@*"), and compares the recorded version/gitCommitSha with the
# plugin's current plugin.json version and git HEAD. When installed, it prints the
# suggestion to run `/plugin update <name>` and `/reload-plugins`.
#
# Usage: check-install-status.sh <plugin-dir> [--json]
set -euo pipefail

die() {
  printf 'check-install-status: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

plugin_dir="."
json=0
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    -*) die "unknown option: $arg" ;;
    "") ;;
    *) plugin_dir="$arg" ;;
  esac
done
plugin_dir="${plugin_dir%/}"
[[ -d "$plugin_dir" ]] || die "plugin directory not found: $plugin_dir"

name="$(jq -r '.name // empty' "$plugin_dir/.claude-plugin/plugin.json" 2>/dev/null || true)"
[[ -n "$name" ]] || die "no plugin name in $plugin_dir/.claude-plugin/plugin.json"
cur_ver="$(jq -r '.version // empty' "$plugin_dir/.claude-plugin/plugin.json" 2>/dev/null || true)"

find_up() {
  local d
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/$2" ]] && {
      printf '%s' "$d"
      return 0
    }
    d="$(dirname "$d")"
  done
  return 1
}

mkt=""
if mp_root="$(find_up "$plugin_dir" .claude-plugin/marketplace.json)"; then
  mkt="$(jq -r '.name // empty' "$mp_root/.claude-plugin/marketplace.json" 2>/dev/null || true)"
fi
cur_sha="$(git -C "$plugin_dir" rev-parse --short HEAD 2>/dev/null || true)"

installed_json="${INSTALLED_PLUGINS_JSON:-$HOME/.claude/plugins/installed_plugins.json}"

emit_json() { # <installed-bool> <records-json>
  jq -n --arg n "$name" --arg m "$mkt" --arg v "$cur_ver" --argjson inst "$1" --argjson recs "$2" \
    '{plugin:$n, marketplace:(if $m=="" then null else $m end),
      currentVersion:$v, installed:$inst, records:$recs, reloadSuggested:$inst}'
}

if [[ ! -f "$installed_json" ]]; then
  if [[ "$json" -eq 1 ]]; then
    emit_json false '[]'
  else
    printf '%s: not installed (no installed_plugins.json at %s) — no reload needed.\n' "$name" "$installed_json"
  fi
  exit 0
fi

# Matching records for this plugin (scoped to its marketplace when known).
records="$(jq -c --arg n "$name" --arg m "$mkt" '
  (.plugins // {}) | to_entries
  | map(select((.key == ($n + "@" + $m)) or ($m == "" and (.key | startswith($n + "@")))))
  | map(.key as $k | .value[] | {key:$k, scope, version, gitCommitSha, installPath})
' "$installed_json" 2>/dev/null || echo '[]')"
[[ -n "$records" ]] || records='[]'

count="$(jq 'length' <<<"$records")"

if [[ "$json" -eq 1 ]]; then
  emit_json "$([[ "$count" -gt 0 ]] && echo true || echo false)" "$records"
  exit 0
fi

if [[ "$count" -eq 0 ]]; then
  printf '%s: not installed / not active in this session — no reload needed.\n' "$name"
  exit 0
fi

printf '%s: installed%s\n' "$name" "$([[ -n "$mkt" ]] && printf ' (marketplace: %s)' "$mkt")"
while IFS= read -r rec; do
  iv="$(jq -r '.version // "?"' <<<"$rec")"
  ish="$(jq -r '.gitCommitSha // "" | .[0:7]' <<<"$rec")"
  isc="$(jq -r '.scope // "?"' <<<"$rec")"
  note=""
  [[ -n "$cur_ver" && "$iv" != "?" && "$iv" != "$cur_ver" ]] && note+=" [version differs: current v$cur_ver]"
  [[ -n "$cur_sha" && -n "$ish" && "$ish" != "$cur_sha" ]] && note+=" [sha differs: HEAD $cur_sha]"
  printf '  - scope=%s installed=v%s sha=%s%s\n' "$isc" "$iv" "${ish:-?}" "$note"
done < <(jq -c '.[]' <<<"$records")

printf '\nYou just edited this plugin, so the installed copy is behind your working tree. Reload it:\n'
printf '  /plugin update %s\n  /reload-plugins\n' "$name"
