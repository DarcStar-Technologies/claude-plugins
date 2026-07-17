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
#   plugin  : {kind:"plugin", name, version?:"<range>"}  (checked via installed_plugins.json)
#             version is an optional Claude Code dependency range (>=, >, <=, <, =/exact,
#             ^, ~) evaluated against the installed version via the semver engine; omit it
#             to check presence only. Evaluation degrades to UNKNOWN when semver is absent.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the semver engine used to evaluate a declared plugin `version` range.
# semver is a SOFT dependency: absent it, range checks degrade to UNKNOWN rather than
# failing — dep-doctor must still verify CLI/library/MCP/plugin-presence without it.
# Resolution mirrors the other consumers: $SEMVER_BIN -> marketplace ancestor -> PATH.
find_semver() {
  if [[ -n "${SEMVER_BIN:-}" && -x "${SEMVER_BIN:-}" ]]; then
    printf '%s' "$SEMVER_BIN"
    return 0
  fi
  local d
  d="$SCRIPT_DIR"
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -x "$d/plugins/semver/scripts/semver.sh" ]] && {
      printf '%s' "$d/plugins/semver/scripts/semver.sh"
      return 0
    }
    d="$(dirname "$d")"
  done
  command -v semver.sh 2>/dev/null && return 0
  return 1
}
SEMVER="$(find_semver || true)"

# range_satisfied <installed> <range> — is <installed> within the constraint <range>?
# Supports the operator forms Claude Code plugin dependencies use: >=, >, <=, <,
# = / bare-exact, ^ (caret), ~ (tilde). Returns 0 = satisfied, 1 = not, 2 = cannot
# evaluate (no semver engine, or an unparseable version/range — the caller reports
# UNKNOWN, never a false WRONG-VERSION).
range_satisfied() {
  local v="$1" r="$2" op base cmp maj min ceil
  [[ -n "$SEMVER" ]] || return 2
  case "$r" in
    ">="*)
      op=">="
      base="${r#>=}"
      ;;
    "<="*)
      op="<="
      base="${r#<=}"
      ;;
    ">"*)
      op=">"
      base="${r#>}"
      ;;
    "<"*)
      op="<"
      base="${r#<}"
      ;;
    "="*)
      op="="
      base="${r#=}"
      ;;
    "^"*)
      op="^"
      base="${r#^}"
      ;;
    "~"*)
      op="~"
      base="${r#\~}"
      ;; # quote ~ so it isn't tilde-EXPANDED to $HOME
    *)
      op="="
      base="$r"
      ;;
  esac
  base="${base# }"
  "$SEMVER" validate "$base" >/dev/null 2>&1 || return 2
  "$SEMVER" validate "$v" >/dev/null 2>&1 || return 2
  cmp="$("$SEMVER" compare "$v" "$base")" || return 2
  case "$op" in
    ">=") [[ "$cmp" -ge 0 ]] ;;
    ">") [[ "$cmp" -gt 0 ]] ;;
    "<=") [[ "$cmp" -le 0 ]] ;;
    "<") [[ "$cmp" -lt 0 ]] ;;
    "=") [[ "$cmp" -eq 0 ]] ;;
    "^")
      # npm caret: >= base and < next non-zero-leftmost boundary. For 0.y.z the
      # left-most non-zero is the minor, so ^0.2.1 => >=0.2.1 <0.3.0.
      [[ "$cmp" -ge 0 ]] || return 1
      maj="$("$SEMVER" major "$base")"
      min="$("$SEMVER" minor "$base")"
      if [[ "$maj" -eq 0 ]]; then ceil="0.$((min + 1)).0"; else ceil="$((maj + 1)).0.0"; fi
      [[ "$("$SEMVER" compare "$v" "$ceil")" -lt 0 ]]
      ;;
    "~")
      # tilde: >= base and < next minor (~1.2.3 => >=1.2.3 <1.3.0).
      [[ "$cmp" -ge 0 ]] || return 1
      maj="$("$SEMVER" major "$base")"
      min="$("$SEMVER" minor "$base")"
      ceil="$maj.$((min + 1)).0"
      [[ "$("$SEMVER" compare "$v" "$ceil")" -lt 0 ]]
      ;;
    *) return 2 ;;
  esac
}

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
      if [[ ! -f "$installed_json" ]]; then
        status="UNKNOWN"
        detail="no installed_plugins.json — cannot verify plugin '$name'"
      else
        # Collect every recorded install version for this plugin. An actual RECORD is
        # required, not merely a key — a stale `"<name>@mkt": []` left by a partial
        # uninstall must not read as installed (matches check-install-status.sh, which
        # iterates .value[]). A record without a `.version` still counts as installed.
        mapfile -t ivs < <(jq -r --arg n "$name" \
          '(.plugins // {}) | to_entries
             | map(select((.key | startswith($n + "@")) and (.value | type == "array")))
             | [.[].value[] | .version // empty] | unique[]' \
          "$installed_json" 2>/dev/null)
        installed_any="$(jq -e --arg n "$name" \
          '(.plugins // {}) | to_entries
             | any((.key | startswith($n + "@")) and (.value | type == "array") and (.value | length > 0))' \
          "$installed_json" >/dev/null 2>&1 && echo yes || echo no)"
        range="$(jq -r '.version // ""' <<<"$el")"
        shown="${ivs[0]:-}"
        if [[ "$installed_any" != "yes" ]]; then
          status="MISSING"
          detail="not present in installed_plugins.json"
        elif [[ -z "$range" ]]; then
          status="OK"
          detail="installed${shown:+ (v$shown)}"
        else
          # OK if ANY recorded version satisfies the range; UNKNOWN only if we could
          # evaluate none (no semver engine, or all versions/range unparseable).
          sat=1
          unk=0
          for iv in ${ivs[@]+"${ivs[@]}"}; do
            # `|| rc=$?` keeps a non-zero range_satisfied from tripping `set -e`
            # before we can read its result.
            rc=0
            range_satisfied "$iv" "$range" || rc=$?
            [[ "$rc" -eq 0 ]] && {
              sat=0
              break
            }
            [[ "$rc" -eq 2 ]] && unk=1
          done
          if [[ "$sat" -eq 0 ]]; then
            status="OK"
            detail="installed${shown:+ (v$shown)} — satisfies $range"
          elif [[ "$unk" -eq 1 || "${#ivs[@]}" -eq 0 ]]; then
            status="UNKNOWN"
            detail="installed${shown:+ (v$shown)} but could not evaluate range $range (semver engine unavailable or version unparseable)"
          else
            status="WRONG-VERSION"
            detail="installed${shown:+ (v$shown)} does not satisfy $range"
          fi
        fi
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
