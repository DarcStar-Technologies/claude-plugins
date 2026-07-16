#!/usr/bin/env bash
# forge-scaffold.sh — portable plugin scaffolder for plugin-forge.
#
# Creates a standalone Claude Code plugin from a resolved template, WITHOUT
# touching any marketplace or release configuration. Unlike the marketplace's
# scripts/new-plugin.sh, this is self-contained: it has no dependency on this
# repository's layout and works in any project.
#
# Usage:
#   forge-scaffold.sh <name> [options]
#
# Options:
#   --description <text>       one-line plugin description
#   --out <dir>                parent directory for the new plugin (default: .)
#   --author <name>            plugin author (default: none)
#   --template-version <ver>   fetch the template at tag _template-v<ver> from
#                              the default repo
#   --template-repo <repo>     fetch the template from <owner/repo>, a git URL, or
#                              a local path; append @<ref> to select a tag/branch
#
# Template resolution (highest precedence first):
#   1. --template-version <ver>       tag _template-v<ver> from the default repo
#   2. --template-repo <repo>[@ref]   the given repo/path
#   3. ./_template                    a local template in the current directory
#   4. (default)                      latest template from the default repo
#
# NOTE: docs/manifest are generated from the small inline scaffolds below, which
# intentionally mirror the repo's templates/*.tmpl. Unifying the two template
# sources is tracked in issue #6 (multiple named templates).
set -euo pipefail

DEFAULT_REPO="https://github.com/DarcStar-Technologies/claude-plugins.git"
TEMPLATE_NAME="_template"

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
out="."
tpl_version=""
tpl_repo=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description) description="${2:?--description needs a value}" && shift 2 ;;
    --author) author="${2:?--author needs a value}" && shift 2 ;;
    --out) out="${2:?--out needs a value}" && shift 2 ;;
    --template-version) tpl_version="${2:?--template-version needs a value}" && shift 2 ;;
    --template-repo) tpl_repo="${2:?--template-repo needs a value}" && shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] ||
  die "plugin name must be lowercase alphanumeric with hyphens (got '$name')"
dest="$out/$name"
[[ ! -e "$dest" ]] || die "destination already exists: $dest"

# --- resolve the template into $tpl_dir ------------------------------------
tmp_clone=""
cleanup() {
  [[ -n "$tmp_clone" ]] && rm -rf "$tmp_clone"
  return 0 # never let the EXIT trap's status become the script's exit code
}
trap cleanup EXIT

# clone_template <git-url-or-path> <ref-or-empty> -> echoes the template dir
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
  printf '%s/plugins/%s' "$tmp_clone" "$TEMPLATE_NAME"
}

tpl_source=""
tpl_dir=""
if [[ -n "$tpl_version" ]]; then
  tpl_dir="$(clone_template "$DEFAULT_REPO" "${TEMPLATE_NAME}-v${tpl_version}")"
  tpl_source="tag:${TEMPLATE_NAME}-v${tpl_version}"
elif [[ -n "$tpl_repo" ]]; then
  ref=""
  url="$tpl_repo"
  [[ "$tpl_repo" == *@* ]] && {
    url="${tpl_repo%@*}"
    ref="${tpl_repo##*@}"
  }
  # owner/repo shorthand -> GitHub URL; leave URLs and local paths untouched.
  [[ "$url" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] && url="https://github.com/${url}.git"
  tpl_dir="$(clone_template "$url" "$ref")"
  tpl_source="repo:${tpl_repo}"
elif [[ -d "./${TEMPLATE_NAME}" ]]; then
  tpl_dir="./${TEMPLATE_NAME}"
  tpl_source="local:./${TEMPLATE_NAME}"
else
  tpl_dir="$(clone_template "$DEFAULT_REPO" "")"
  tpl_source="default:${DEFAULT_REPO}"
fi

[[ -d "$tpl_dir" ]] || die "resolved template not found: $tpl_dir"
[[ -f "$tpl_dir/.claude-plugin/plugin.json" ]] ||
  die "template has no .claude-plugin/plugin.json: $tpl_dir"
tpl_ver="$(jq -r '.version // "unknown"' "$tpl_dir/.claude-plugin/plugin.json")"

# --- scaffold --------------------------------------------------------------
info "scaffolding $dest (template source: $tpl_source)"
mkdir -p "$dest/.claude-plugin"

# Copy component directories from the template, then rename the identifier.
for comp in commands agents skills scripts; do
  [[ -d "$tpl_dir/$comp" ]] || continue
  cp -R "$tpl_dir/$comp" "$dest/$comp"
done
if [[ -n "$(find "$dest" -type f -print -quit 2>/dev/null)" ]]; then
  while IFS= read -r -d '' f; do
    content="$(cat "$f")"
    content="${content//"$TEMPLATE_NAME"/$name}"
    printf '%s' "$content" >"$f"
  done < <(grep -rlZ -F --binary-files=without-match "$TEMPLATE_NAME" "$dest" 2>/dev/null || true)
fi

# Generate the manifest (identity only; drop any repo-specific fields).
jq -n --arg name "$name" --arg desc "$description" --arg author "$author" \
  '{name: $name, version: "0.1.0", description: $desc}
   + (if $author == "" then {} else {author: {name: $author}} end)
   + {license: "MIT", keywords: []}' \
  >"$dest/.claude-plugin/plugin.json"

# Generate docs from inline scaffolds (mirror of templates/*.tmpl — see note).
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
EOF
)" >"$dest/README.md"

render "$(
  cat <<'EOF'
# {{NAME}} — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

{{DESC}}

## Mental model

_Describe the core idea and the one concept a newcomer must understand first._

## Challenging concepts & gotchas

_Document ordering constraints, external dependencies, and known failure modes._
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

# Provenance: portable mode records the resolved source and template version.
today="$(date +%Y-%m-%d)"
jq -n --arg tpl "$TEMPLATE_NAME" --arg tver "$tpl_ver" --arg src "$tpl_source" --arg date "$today" \
  '{template: $tpl, templateVersion: $tver, source: $src, mode: "portable", scaffoldedWith: "forge-scaffold.sh", scaffoldedAt: $date}' \
  >"$dest/.claude-plugin/scaffold.json"

info "done: $dest"
printf 'Next: flesh out %s/CONTEXT.md, README.md, and the components.\n' "$dest"
