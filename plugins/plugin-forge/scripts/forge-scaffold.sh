#!/usr/bin/env bash
# forge-scaffold.sh — the single scaffolder for plugin-forge.
#
# Creates a new Claude Code plugin from a resolved template. The two modes differ
# only in registration:
#   - portable (default): write a standalone plugin into --out; register nothing.
#   - marketplace (--register <repo-root>): write into <root>/plugins/<name> and
#     register it in that repo's marketplace catalog + release automation.
#
# Usage:
#   forge-scaffold.sh <name> [--description T] [--author A] [--template NAME]
#                     [--out DIR] [--register REPO_ROOT]
#                     [--template-version VER | --template-repo REPO[@REF]]
#
# Template resolution (highest precedence first):
#   0. --register <root>        -> <root>/plugins/<template> (marketplace)
#   1. --template-version VER   -> tag <template>-vVER from the default repo
#   2. --template-repo REPO     -> owner/repo, a git URL, or a local path (+@ref)
#   3. ./<template>             -> a local template directory
#   4. (default)                -> latest <template> from the default repo
#
# Only components (commands/agents/skills/scripts) are taken from the template;
# docs and the manifest are generated from the inline scaffolds below. A custom
# template therefore contributes components, not docs — see issue #6.
set -euo pipefail

DEFAULT_REPO="https://github.com/DarcStar-Technologies/claude-plugins.git"

die() {
  printf 'forge-scaffold: %s\n' "$*" >&2
  exit 1
}
info() { printf '==> %s\n' "$*"; }

command -v git >/dev/null 2>&1 || die "git is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

# --- arguments -------------------------------------------------------------
name="${1:-}"
[[ -n "$name" && "$name" != -* ]] || die "usage: forge-scaffold.sh <name> [options]"
shift

description="A Claude Code plugin."
author=""
template="_template"
out="."
register_root=""
tpl_version=""
tpl_repo=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description) description="${2:?--description needs a value}" && shift 2 ;;
    --author) author="${2:?--author needs a value}" && shift 2 ;;
    --template) template="${2:?--template needs a value}" && shift 2 ;;
    --out) out="${2:?--out needs a value}" && shift 2 ;;
    --register) register_root="${2:?--register needs a repo root}" && shift 2 ;;
    --template-version) tpl_version="${2:?--template-version needs a value}" && shift 2 ;;
    --template-repo) tpl_repo="${2:?--template-repo needs a value}" && shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] ||
  die "plugin name must be lowercase alphanumeric with hyphens (got '$name')"

if [[ -n "$register_root" ]]; then
  [[ -d "$register_root" ]] || die "register root not found: $register_root"
  [[ -f "$register_root/.claude-plugin/marketplace.json" ]] ||
    die "register root is not a marketplace (no .claude-plugin/marketplace.json): $register_root"
  dest="$register_root/plugins/$name"
else
  dest="$out/$name"
fi
[[ ! -e "$dest" ]] || die "destination already exists: $dest"

# --- resolve the template into $tpl_dir ------------------------------------
tmp_clone=""
cleanup() {
  [[ -n "$tmp_clone" ]] && rm -rf "$tmp_clone"
  return 0 # never let the EXIT trap's status become the script's exit code
}
trap cleanup EXIT

clone_template() {
  local url="$1" ref="$2"
  tmp_clone="$(mktemp -d)"
  if [[ -n "$ref" ]]; then
    git clone --depth 1 --branch "$ref" -- "$url" "$tmp_clone" >/dev/null 2>&1 ||
      die "could not fetch ref '$ref' from '$url'"
  else
    git clone --depth 1 -- "$url" "$tmp_clone" >/dev/null 2>&1 ||
      die "could not fetch '$url'"
  fi
  printf '%s/plugins/%s' "$tmp_clone" "$template"
}

tpl_source=""
tpl_dir=""
if [[ -n "$register_root" ]]; then
  tpl_dir="$register_root/plugins/$template"
  tpl_source="repo:$register_root"
elif [[ -n "$tpl_version" ]]; then
  tpl_dir="$(clone_template "$DEFAULT_REPO" "${template}-v${tpl_version}")"
  tpl_source="tag:${template}-v${tpl_version}"
elif [[ -n "$tpl_repo" ]]; then
  ref=""
  url="$tpl_repo"
  # Split @ref only for non-URL / non-SSH forms (a URL or git@host:path has ://
  # or a ':' host separator — don't mangle it).
  if [[ "$tpl_repo" != *://* && "$tpl_repo" != *:* && "$tpl_repo" == *@* ]]; then
    url="${tpl_repo%@*}"
    ref="${tpl_repo##*@}"
  fi
  # owner/repo shorthand -> GitHub URL, but only when it isn't an existing local
  # directory (a local path like myorg/myrepo takes precedence over the shorthand).
  if [[ ! -d "$url" && "$url" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    url="https://github.com/${url}.git"
  fi
  tpl_dir="$(clone_template "$url" "$ref")"
  tpl_source="repo:${tpl_repo}"
elif [[ -d "./${template}" ]]; then
  tpl_dir="./${template}"
  tpl_source="local:./${template}"
else
  tpl_dir="$(clone_template "$DEFAULT_REPO" "")"
  tpl_source="default:${DEFAULT_REPO}"
fi

[[ -d "$tpl_dir" ]] || die "resolved template not found: $tpl_dir"
[[ -f "$tpl_dir/.claude-plugin/plugin.json" ]] ||
  die "template has no .claude-plugin/plugin.json: $tpl_dir"
tpl_ver="$(jq -r '.version // "unknown"' "$tpl_dir/.claude-plugin/plugin.json")"
tpl_license="$(jq -r '.license // "MIT"' "$tpl_dir/.claude-plugin/plugin.json")"

# --- scaffold --------------------------------------------------------------
mode="portable"
[[ -n "$register_root" ]] && mode="marketplace"
info "scaffolding $dest (mode: $mode, template source: $tpl_source)"
mkdir -p "$dest/.claude-plugin"

# Components come from the template (identifier renamed to the new plugin name).
for comp in commands agents skills scripts; do
  [[ -d "$tpl_dir/$comp" ]] || continue
  cp -R "$tpl_dir/$comp" "$dest/$comp"
done
if [[ -n "$(find "$dest" -type f -print -quit 2>/dev/null)" ]]; then
  while IFS= read -r -d '' f; do
    content="$(cat "$f")"
    content="${content//"$template"/$name}"
    printf '%s' "$content" >"$f"
  done < <(grep -rlZ -F --binary-files=without-match "$template" "$dest" 2>/dev/null || true)
fi

# Manifest: identity only; the license is inherited from the template.
jq -n --arg name "$name" --arg desc "$description" --arg author "$author" --arg license "$tpl_license" \
  '{name: $name, version: "0.1.0", description: $desc}
   + (if $author == "" then {} else {author: {name: $author}} end)
   + {license: $license, keywords: []}' \
  >"$dest/.claude-plugin/plugin.json"

# Docs from inline scaffolds.
render() {
  local c="$1"
  c="${c//\{\{NAME\}\}/$name}"
  c="${c//\{\{DESC\}\}/$description}"
  printf '%s\n' "$c"
}

render "$(
  cat <<'EOF'
# {{NAME}}

{{DESC}}

## Usage

_Document the commands, agents, and skills this plugin provides._

## Development

See `CONTEXT.md` for design notes and `CHANGELOG.md` for release history.
EOF
)" >"$dest/README.md"

render "$(
  cat <<'EOF'
# {{NAME}} — Context

> Orientation for humans and AI assistants working on this plugin. It explains
> the *why* and the non-obvious concepts. Keep it current as the plugin evolves.

## Purpose

{{DESC}}

## Mental model

_Describe the core idea in a few sentences: what problem does this plugin solve,
and what is the one concept a newcomer must understand first?_

## Components

| Path        | Type           | Responsibility                            |
| ----------- | -------------- | ----------------------------------------- |
| `commands/` | Slash commands | User-invoked entry points.                |
| `agents/`   | Subagents      | Delegated, task-scoped workers.           |
| `skills/`   | Skills         | Model-invoked capabilities and knowledge. |
| `scripts/`  | Shell          | Deterministic, mechanized steps (no LLM). |

## Model selection

Use the **minimum capable model** for each subagent or command (`model:`
frontmatter): `haiku` for mechanical/bounded work, `sonnet` for moderate
reasoning, `opus` for deep or ambiguous problems. Push anything fully
deterministic into `scripts/` so no model is spent on it.

## Challenging concepts & gotchas

_Document ordering constraints, external dependencies, environment assumptions,
and known failure modes here._
EOF
)" >"$dest/CONTEXT.md"

render "$(
  cat <<'EOF'
# Changelog

All notable changes to the `{{NAME}}` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial scaffold of the `{{NAME}}` plugin.
EOF
)" >"$dest/CHANGELOG.md"

# Provenance: template + resolved source + mode.
today="$(date +%Y-%m-%d)"
jq -n --arg tpl "$template" --arg tver "$tpl_ver" --arg src "$tpl_source" --arg mode "$mode" --arg date "$today" \
  '{template: $tpl, templateVersion: $tver, source: $src, mode: $mode, scaffoldedWith: "forge-scaffold.sh", scaffoldedAt: $date}' \
  >"$dest/.claude-plugin/scaffold.json"

# --- register (marketplace mode only) --------------------------------------
if [[ -n "$register_root" ]]; then
  tmp="$(mktemp)"
  mp="$register_root/.claude-plugin/marketplace.json"
  # No version field: plugin.json is the source of truth (release-please updates
  # it, not the catalog, so a version here would drift).
  jq --arg name "$name" --arg src "./plugins/$name" --arg desc "$description" \
    '.plugins += [{name: $name, source: $src, description: $desc}]' "$mp" >"$tmp" && mv "$tmp" "$mp"

  cfg="$register_root/release-please-config.json"
  if [[ -f "$cfg" ]]; then
    tmp="$(mktemp)"
    jq --arg path "plugins/$name" --arg comp "$name" \
      '.packages[$path] = {
          "release-type": "simple",
          "component": $comp,
          "changelog-path": "CHANGELOG.md",
          "extra-files": [
            {"type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version"}
          ]
        }' "$cfg" >"$tmp" && mv "$tmp" "$cfg"
  fi

  man="$register_root/.release-please-manifest.json"
  if [[ -f "$man" ]]; then
    tmp="$(mktemp)"
    # Seed at 0.0.0 so release-please cuts a clean 0.1.0 as the first release.
    jq --arg path "plugins/$name" '.[$path] = "0.0.0"' "$man" >"$tmp" && mv "$tmp" "$man"
  fi
  info "registered $name in the marketplace"
fi

info "done: $dest"
