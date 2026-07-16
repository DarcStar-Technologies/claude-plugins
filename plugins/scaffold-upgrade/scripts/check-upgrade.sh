#!/usr/bin/env bash
# check-upgrade.sh — report whether a scaffolded plugin is behind its source
# template. Read-only: it inspects, it never modifies the target plugin.
#
# Usage:
#   check-upgrade.sh [plugin-dir] [--json]
#
# It reads <plugin-dir>/.claude-plugin/scaffold.json (the provenance the
# scaffolder records: template + templateVersion + source), determines the latest
# available version of that same template, and reports the upgrade status, the
# semver gap, and — when the template's CHANGELOG is reachable — what changed.
#
# Version math reuses the semver plugin's engine, resolved at RUN TIME (no vendored
# copy). Resolution order: $SEMVER_BIN -> a marketplace ancestor's
# plugins/semver/scripts/semver.sh -> semver.sh on $PATH. If none is found the
# tool exits with a clear message.
#
# The template's latest version is resolved from the recorded `source`:
#   1. an ancestor marketplace checkout (templates/<name>) — the in-repo case,
#   2. a local path embedded in the source,
#   3. the <name>-v* release tags of the recorded (or default) repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO="${SCAFFOLD_UPGRADE_DEFAULT_REPO:-https://github.com/DarcStar-Technologies/claude-plugins.git}"

die() {
  printf 'check-upgrade: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"
command -v git >/dev/null 2>&1 || die "git is required"

# --- arguments -------------------------------------------------------------
plugin_dir="."
json=0
for arg in "$@"; do
  case "$arg" in
    --json) json=1 ;;
    -*) die "unknown option: $arg" ;;
    "") ;; # ignore empty arg (e.g. an unquoted-empty $ARGUMENTS from the command)
    *) plugin_dir="$arg" ;;
  esac
done
plugin_dir="${plugin_dir%/}"
[[ -d "$plugin_dir" ]] || die "plugin directory not found: $plugin_dir"

scaffold="$plugin_dir/.claude-plugin/scaffold.json"
[[ -f "$scaffold" ]] ||
  die "no provenance at $scaffold — this plugin was not scaffolded by plugin-forge (nothing to compare against a template)"
jq empty "$scaffold" 2>/dev/null || die "scaffold.json is not valid JSON: $scaffold"

tmpl="$(jq -r '.template // empty' "$scaffold")"
recorded="$(jq -r '.templateVersion // empty' "$scaffold")"
source_str="$(jq -r '.source // empty' "$scaffold")"
[[ -n "$tmpl" ]] || die "scaffold.json has no 'template' field"
[[ -n "$recorded" ]] || die "scaffold.json has no 'templateVersion' field"

plugin_name="$(jq -r '.name // empty' "$plugin_dir/.claude-plugin/plugin.json" 2>/dev/null || true)"
[[ -n "$plugin_name" ]] || plugin_name="$(basename "$(cd "$plugin_dir" && pwd)")"

# --- resolve the semver engine at run time ---------------------------------
find_semver() {
  if [[ -n "${SEMVER_BIN:-}" && -x "${SEMVER_BIN:-}" ]]; then
    printf '%s' "$SEMVER_BIN"
    return 0
  fi
  local start d
  for start in "$plugin_dir" "$SCRIPT_DIR"; do
    d="$(cd "$start" 2>/dev/null && pwd)" || d=""
    while [[ -n "$d" && "$d" != "/" ]]; do
      if [[ -x "$d/plugins/semver/scripts/semver.sh" ]]; then
        printf '%s' "$d/plugins/semver/scripts/semver.sh"
        return 0
      fi
      d="$(dirname "$d")"
    done
  done
  command -v semver.sh 2>/dev/null && return 0
  return 1
}
semver="$(find_semver)" ||
  die "semver engine not found — install the semver plugin, put semver.sh on PATH, or set SEMVER_BIN (this tool reuses it rather than bundling a copy)"

# --- resolve the template's latest version ---------------------------------
tmp_clone=""
cleanup() {
  [[ -n "$tmp_clone" ]] && rm -rf "$tmp_clone"
  return 0
}
trap cleanup EXIT

# A template dir is a directory holding .claude-plugin/plugin.json; templates sit
# at templates/<name> in a marketplace, or <name> at a template-repo root.
template_dir_in() {
  local root="$1" d
  for d in "$root/templates/$tmpl" "$root/$tmpl"; do
    [[ -f "$d/.claude-plugin/plugin.json" ]] && {
      printf '%s' "$d"
      return 0
    }
  done
  return 1
}
version_in() { jq -r '.version // empty' "$1/.claude-plugin/plugin.json"; }

latest=""
template_dir=""
resolved_from=""

# 1. ancestor marketplace walk (in-repo; no network).
d="$(cd "$plugin_dir" 2>/dev/null && pwd)" || d=""
while [[ -n "$d" && "$d" != "/" ]]; do
  if [[ -f "$d/.claude-plugin/marketplace.json" ]] && td="$(template_dir_in "$d")"; then
    v="$(version_in "$td")"
    if [[ -n "$v" ]]; then
      latest="$v"
      template_dir="$td"
      resolved_from="marketplace:$d"
      break
    fi
  fi
  d="$(dirname "$d")"
done

# 2. a local path embedded in the source (local:<path> / repo:<localpath>).
if [[ -z "$latest" ]]; then
  case "$source_str" in
    local:* | repo:*)
      spec="${source_str#*:}"
      [[ "$source_str" == repo:* && "$spec" != *://* && "$spec" != *:*/* && "$spec" == *@* ]] && spec="${spec%@*}"
      if [[ -d "$spec" ]] && td="$(template_dir_in "$spec")"; then
        v="$(version_in "$td")"
        if [[ -n "$v" ]]; then
          latest="$v"
          template_dir="$td"
          resolved_from="local:$spec"
        fi
      fi
      ;;
  esac
fi

# 3. remote <name>-v* tags of the recorded (or default) repo.
if [[ -z "$latest" ]]; then
  url=""
  case "$source_str" in
    tag:*) url="$DEFAULT_REPO" ;;
    default:*) url="${source_str#default:}" ;;
    repo:*)
      spec="${source_str#repo:}"
      [[ "$spec" != *://* && "$spec" != *:*/* && "$spec" == *@* ]] && spec="${spec%@*}"
      if [[ ! -d "$spec" && "$spec" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
        url="https://github.com/${spec}.git"
      else
        url="$spec"
      fi
      ;;
    "") url="$DEFAULT_REPO" ;; # no source recorded: try the default upstream
  esac

  if [[ -n "$url" && "$url" != /* && ! -d "$url" ]] || [[ -d "$url" ]]; then
    best=""
    while IFS= read -r v; do
      [[ -n "$v" ]] || continue
      "$semver" validate "$v" >/dev/null 2>&1 || continue
      if [[ -z "$best" || "$("$semver" compare "$v" "$best")" == "1" ]]; then best="$v"; fi
    done < <(git ls-remote --tags "$url" "refs/tags/${tmpl}-v*" 2>/dev/null |
      sed -E "s#.*refs/tags/${tmpl}-v##; s/\\^\\{\\}\$//" | sort -u)
    if [[ -n "$best" ]]; then
      latest="$best"
      resolved_from="tags:$url"
      tmp_clone="$(mktemp -d)"
      if git clone --depth 1 --branch "${tmpl}-v${best}" -- "$url" "$tmp_clone" >/dev/null 2>&1; then
        template_dir="$(template_dir_in "$tmp_clone" || true)"
      fi
    fi
  fi
fi

# --- classify --------------------------------------------------------------
status="unresolved"
gap="null"
if [[ -n "$latest" ]]; then
  if ! "$semver" validate "$recorded" >/dev/null 2>&1 || ! "$semver" validate "$latest" >/dev/null 2>&1; then
    status="unknown-version"
  else
    cmp="$("$semver" compare "$latest" "$recorded")"
    case "$cmp" in
      0) status="up-to-date" ;;
      1)
        status="upgrade-available"
        gap="$("$semver" diff "$recorded" "$latest")"
        ;;
      -1) status="ahead" ;; # recorded newer than the resolved latest
    esac
  fi
fi

# --- what changed (template CHANGELOG between recorded and latest) ----------
# Prints the template's CHANGELOG sections newer than the recorded version.
changelog_since() {
  local file="$1"
  awk -v rec="$recorded" '
    function ver(line,   v) {
      v = line
      sub(/^##[[:space:]]+/, "", v)
      sub(/^\[/, "", v)
      sub(/[] (].*/, "", v)   # cut at the first ] ( or space
      return v
    }
    /^##[[:space:]]/ {
      v = ver($0)
      if (v == rec) exit                            # reached the recorded version
      printing = (v ~ /^[0-9]+\.[0-9]+\.[0-9]+/)    # only real release sections
    }
    printing { print }
  ' "$file"
}
changed=""
if [[ "$status" == "upgrade-available" && -n "$template_dir" && -f "$template_dir/CHANGELOG.md" ]]; then
  changed="$(changelog_since "$template_dir/CHANGELOG.md")"
fi

# --- output ----------------------------------------------------------------
if [[ "$json" -eq 1 ]]; then
  jq -n \
    --arg plugin "$plugin_name" --arg template "$tmpl" \
    --arg scaffolded "$recorded" --arg latest "$latest" \
    --arg status "$status" --arg gap "$gap" \
    --arg from "$resolved_from" --arg changed "$changed" \
    '{plugin:$plugin, template:$template, scaffoldedVersion:$scaffolded,
      latestVersion:(if $latest=="" then null else $latest end),
      status:$status, gap:(if $gap=="null" then null else $gap end),
      resolvedFrom:(if $from=="" then null else $from end),
      changed:(if $changed=="" then null else $changed end)}'
  exit 0
fi

printf 'plugin:   %s\n' "$plugin_name"
printf 'template: %s  (scaffolded from v%s)\n' "$tmpl" "$recorded"
case "$status" in
  up-to-date) printf 'status:   up to date — v%s is the latest [%s]\n' "$latest" "$resolved_from" ;;
  upgrade-available)
    printf 'latest:   v%s  [%s]\n' "$latest" "$resolved_from"
    printf 'status:   UPGRADE AVAILABLE (%s: v%s -> v%s)\n' "$gap" "$recorded" "$latest"
    if [[ -n "$changed" ]]; then
      printf '\nchanges in the template since v%s:\n' "$recorded"
      printf '%s\n' "$changed" | sed 's/^/  /'
    fi
    ;;
  ahead) printf 'status:   ahead — recorded v%s is newer than the resolved latest v%s [%s]\n' "$recorded" "$latest" "$resolved_from" ;;
  unknown-version) printf 'status:   unknown — recorded (v%s) or latest (v%s) is not valid semver\n' "$recorded" "$latest" ;;
  unresolved) printf 'status:   could not resolve the latest version of template %s from source %s\n' "$tmpl" "${source_str:-<none>}" ;;
esac
