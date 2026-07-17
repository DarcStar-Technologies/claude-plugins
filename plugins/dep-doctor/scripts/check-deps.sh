#!/usr/bin/env bash
# check-deps.sh — deterministic, READ-ONLY dependency checker for dep-doctor. Reads a
# JSON array of dependency descriptors (from a <file> arg or stdin) and classifies each
# OK | MISSING | WRONG-VERSION | UNKNOWN, emitting the array augmented with `status` and
# `detail`. It never installs or mutates anything — it only probes.
#
# Descriptor fields by kind:
#   cli     : {kind:"cli", name, versionFlag?:"--version", versionPattern?:"<ERE>"}
#             versionFlag is allow-listed (--version|-version|--v|-V|-v|version); anything
#             else means the version is not probed. It is NEVER a free-form arg array.
#   library : {kind:"library", name, runtime:"python|python3|node|ruby", module}
#   mcp     : {kind:"mcp", name}     (checked via `claude mcp list` when available)
#   plugin  : {kind:"plugin", name}  (checked via installed_plugins.json)
#
# Exit: 0 when every dependency is OK or UNKNOWN; 1 when any is MISSING or WRONG-VERSION.
#
# Usage: check-deps.sh [deps.json]     (or pipe the JSON array on stdin)
set -euo pipefail

die() {
  printf 'check-deps: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

input="$(cat -- "${1:-/dev/stdin}")"
jq -e 'type == "array"' >/dev/null 2>&1 <<<"$input" ||
  die "input must be a JSON array of dependency descriptors"
jq -e 'all(.[]; type == "object")' >/dev/null 2>&1 <<<"$input" ||
  die "every dependency descriptor must be a JSON object"

installed_json="${INSTALLED_PLUGINS_JSON:-$HOME/.claude/plugins/installed_plugins.json}"

# A module/runtime name we will interpolate into an interpreter probe must be a plain
# identifier, so a descriptor can't smuggle code into `python -c "import <module>"`.
safe_id() { [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; }

# Split the input once; build each augmented row independently and slurp once at the
# end (avoids re-parsing the input and re-serializing a growing result per iteration).
mapfile -t els < <(jq -c '.[]' <<<"$input")
results=()
overall=0

for el in ${els[@]+"${els[@]}"}; do
  kind="$(jq -r '.kind // "unknown"' <<<"$el")"
  name="$(jq -r '.name // ""' <<<"$el")"
  status="UNKNOWN"
  detail=""

  case "$kind" in
    cli)
      if command -v "$name" >/dev/null 2>&1; then
        pattern="$(jq -r '.versionPattern // ""' <<<"$el")"
        if [[ -n "$pattern" ]]; then
          # The version flag is restricted to a small ALLOW-LIST so a descriptor can't
          # smuggle arbitrary arguments (e.g. `-c "curl … | sh"`) into `$name`. Anything
          # else means "don't run a version probe".
          flag="$(jq -r '.versionFlag // "--version"' <<<"$el")"
          case "$flag" in
            --version | -version | --v | -V | -v | version) ;;
            *) flag="" ;;
          esac
          if [[ -z "$flag" ]]; then
            status="UNKNOWN"
            detail="present, but versionFlag is not allow-listed — version not checked"
          else
            out="$("$name" "$flag" 2>&1 || true)"
            if grep -Eq -- "$pattern" <<<"$out"; then
              status="OK"
              detail="present, version matches /$pattern/"
            else
              status="WRONG-VERSION"
              detail="present but version did not match /$pattern/"
            fi
          fi
        else
          status="OK"
          detail="present on PATH"
        fi
      else
        status="MISSING"
        detail="command not found: $name"
      fi
      ;;
    library)
      runtime="$(jq -r '.runtime // ""' <<<"$el")"
      module="$(jq -r '.module // .name' <<<"$el")"
      if ! safe_id "$module"; then
        status="UNKNOWN"
        detail="module name '$module' is not a plain identifier — not probing"
      elif ! command -v "$runtime" >/dev/null 2>&1; then
        status="UNKNOWN"
        detail="runtime '$runtime' not found — cannot probe library '$module'"
      else
        ok=1
        case "$runtime" in
          python | python3) "$runtime" -c "import ${module}" >/dev/null 2>&1 || ok=0 ;;
          node) "$runtime" -e "require('${module}')" >/dev/null 2>&1 || ok=0 ;;
          ruby) "$runtime" -e "require '${module}'" >/dev/null 2>&1 || ok=0 ;;
          *) ok=2 ;;
        esac
        case "$ok" in
          1)
            status="OK"
            detail="$runtime can import '$module'"
            ;;
          0)
            status="MISSING"
            detail="$runtime cannot import '$module'"
            ;;
          *)
            status="UNKNOWN"
            detail="unsupported runtime '$runtime'"
            ;;
        esac
      fi
      ;;
    mcp)
      if command -v claude >/dev/null 2>&1; then
        if claude mcp list 2>/dev/null | grep -Fqiw -- "$name"; then
          status="OK"
          detail="configured (in 'claude mcp list')"
        else
          status="MISSING"
          detail="not found in 'claude mcp list'"
        fi
      else
        status="UNKNOWN"
        detail="claude CLI not available — verify MCP server '$name' manually"
      fi
      ;;
    plugin)
      if [[ -f "$installed_json" ]]; then
        # Require an actual install RECORD, not merely a key — a stale `"<name>@mkt": []`
        # left by a partial uninstall must not read as installed (matches
        # check-install-status.sh, which iterates .value[]).
        if jq -e --arg n "$name" \
          '(.plugins // {}) | to_entries
             | any((.key | startswith($n + "@")) and (.value | type == "array") and (.value | length > 0))' \
          "$installed_json" >/dev/null 2>&1; then
          status="OK"
          detail="installed"
        else
          status="MISSING"
          detail="not present in installed_plugins.json"
        fi
      else
        status="UNKNOWN"
        detail="no installed_plugins.json — cannot verify plugin '$name'"
      fi
      ;;
    *)
      status="UNKNOWN"
      detail="unknown dependency kind: $kind"
      ;;
  esac

  [[ "$status" == "MISSING" || "$status" == "WRONG-VERSION" ]] && overall=1
  results+=("$(jq -cn --argjson el "$el" --arg s "$status" --arg d "$detail" \
    '$el + {status: $s, detail: $d}')")
done

if [[ "${#results[@]}" -eq 0 ]]; then
  printf '[]\n'
else
  printf '%s\n' "${results[@]}" | jq -s '.'
fi
exit "$overall"
