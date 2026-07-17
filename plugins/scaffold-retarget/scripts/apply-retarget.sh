#!/usr/bin/env bash
# apply-retarget.sh — mechanically realize an APPROVED /scaffold-retarget plan. Operates
# only inside the target plugin directory; never writes outside it.
#
# Given the plugin dir, the target template snapshot, the plugin's identity, the target
# version, and the approved per-file decisions, it:
#   - update/add : renders <target>/<path> ({{NAME}}/{{DESC}} -> the plugin's OWN identity)
#                  into <plugin>/<path>;
#   - delete     : removes <plugin>/<path>;
#   - keep/none  : leaves the file untouched;
# then updates .claude-plugin/scaffold.json's templateVersion and appends a CHANGELOG
# [Unreleased] entry. It NEVER touches plugin.json's name/description or re-introduces
# {{NAME}}/{{DESC}} placeholders (identity is preserved).
#
# Usage:
#   apply-retarget.sh --plugin <dir> --target <dir> --name <n> --desc <d>
#                     --to-version <v> [--from-version <v>] --decisions <json-array>
# where <json-array> is [{"path":"commands/x.md","action":"update|add|delete|keep"}, ...].
set -euo pipefail

die() {
  printf 'apply-retarget: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

plugin="" target="" name="" desc="" to_version="" from_version="" decisions=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin) plugin="${2:?}" && shift 2 ;;
    --target) target="${2:?}" && shift 2 ;;
    --name) name="${2:?}" && shift 2 ;;
    --desc) desc="${2-}" && shift 2 ;;
    --to-version) to_version="${2:?}" && shift 2 ;;
    --from-version) from_version="${2:?}" && shift 2 ;;
    --decisions) decisions="${2:?}" && shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done
[[ -d "$plugin" && -d "$target" && -n "$name" && -n "$to_version" && -n "$decisions" ]] ||
  die "missing required argument (need --plugin --target --name --to-version --decisions)"
plugin="${plugin%/}"
[[ -f "$plugin/.claude-plugin/plugin.json" ]] || die "not a plugin dir (no plugin.json): $plugin"
jq -e 'type == "array"' >/dev/null 2>&1 <<<"$decisions" || die "--decisions must be a JSON array"

# `&`-safe render (see diff-components.sh).
render() {
  local c="$1" before after
  c="${c//\{\{NAME\}\}/$name}"
  while [[ "$c" == *'{{DESC}}'* ]]; do
    before="${c%%\{\{DESC\}\}*}"
    after="${c#*\{\{DESC\}\}}"
    c="${before}${desc}${after}"
  done
  printf '%s' "$c"
}

# A decision path must stay inside the plugin's component dirs — never absolute, no `..`,
# and rooted at commands/agents/skills/scripts (the only things a template owns).
safe_rel() {
  local p="$1"
  [[ "$p" != /* && "$p" != *..* ]] || return 1
  case "$p" in commands/* | agents/* | skills/* | scripts/*) return 0 ;; *) return 1 ;; esac
}

applied=0
while IFS= read -r row; do
  [[ -n "$row" ]] || continue
  path="$(jq -r '.path' <<<"$row")"
  action="$(jq -r '.action' <<<"$row")"
  safe_rel "$path" || die "refusing unsafe or out-of-scope path in decisions: '$path'"
  case "$action" in
    update | add)
      [[ -f "$target/$path" ]] || die "target has no file to $action: $path"
      mkdir -p "$plugin/$(dirname "$path")"
      render "$(cat "$target/$path")" >"$plugin/$path"
      applied=$((applied + 1))
      ;;
    delete)
      rm -f "$plugin/$path"
      applied=$((applied + 1))
      ;;
    keep | none) ;; # leave the plugin's file as-is
    *) die "unknown decision action '$action' for '$path'" ;;
  esac
done < <(jq -c '.[]' <<<"$decisions")

# Update provenance: the plugin now tracks the target template version.
scaffold="$plugin/.claude-plugin/scaffold.json"
[[ -f "$scaffold" ]] || die "no scaffold.json to update: $scaffold"
tmp="$(mktemp)"
jq --arg v "$to_version" '.templateVersion = $v' "$scaffold" >"$tmp" && mv "$tmp" "$scaffold"

# Record the retarget in the plugin's CHANGELOG [Unreleased] > Changed section. Reuse an
# existing ### Changed under [Unreleased] if present (don't create a duplicate heading);
# otherwise add one right after [Unreleased].
changelog="$plugin/CHANGELOG.md"
tmpl="$(jq -r '.template // "template"' "$scaffold")"
bullet="- Retarget from ${tmpl} v${from_version:-?} to v${to_version} (${applied} component file(s) changed)."
if [[ -f "$changelog" ]] && grep -q '^## \[Unreleased\]' "$changelog"; then
  tmp="$(mktemp)"
  if awk '/^## \[Unreleased\]/{u=1;next} u&&/^## /{exit} u&&/^### Changed/{f=1;exit} END{exit !f}' "$changelog"; then
    # [Unreleased] already has a ### Changed — insert the bullet as its first item.
    awk -v b="$bullet" '
      { if (after) { print; print b; after=0; next } print }
      /^## \[Unreleased\]/ { seen=1 }
      seen && /^### Changed/ && !done { after=1; done=1 }
    ' "$changelog" >"$tmp"
  else
    # No ### Changed under [Unreleased] — create one right after the header.
    awk -v b="$bullet" '
      { print }
      /^## \[Unreleased\]/ && !done { print ""; print "### Changed"; print ""; print b; done=1 }
    ' "$changelog" >"$tmp"
  fi
  mv "$tmp" "$changelog"
fi

printf 'applied %d change(s); templateVersion -> %s\n' "$applied" "$to_version"
