#!/usr/bin/env bash
# template-forge-scaffold.sh — the deterministic scaffolder for template-forge.
#
# Creates a new *reference template* under templates/ (the internal plugins the
# marketplace scaffolder copies component dirs from). A template is just a plugin
# that lives under templates/ instead of plugins/, so it is NEVER added to
# marketplace.json — that omission is exactly what keeps it internal — but it IS
# registered for release management (release-please config + manifest).
#
# Usage:
#   template-forge-scaffold.sh <name> [--description T] [--author A]
#       [--components "commands agents skills scripts"]
#       [--from-plugin <plugin-dir>]
#       [--register <repo-root>] [--out DIR]
#
# Content modes:
#   - default: create empty component dirs for each type in --components (the
#     calling command authors the {{NAME}}/{{DESC}} example components into them).
#   - --from-plugin <dir>: copy that plugin's component dirs into the template,
#     textually substituting the source plugin's name -> {{NAME}} and its
#     description -> {{DESC}} (the inverse of forge-scaffold.sh's placeholder ->
#     identity copy). This reverse is BEST-EFFORT string replacement, not semantic
#     understanding — the calling command/model reconciles whatever it can't safely
#     auto-replace. --components is ignored here (the plugin's own component set
#     determines what is copied).
#
# Registration modes:
#   - without --register: write the template into <out>/<name> (default .); register
#     nothing (useful for tests / previews).
#   - --register <repo-root>: write into <repo-root>/templates/<name> and register
#     it there — a templates/<name> package in release-please-config.json and a
#     0.0.0 seed in .release-please-manifest.json. marketplace.json is never touched.
set -euo pipefail

die() {
  printf 'template-forge-scaffold: %s\n' "$*" >&2
  exit 1
}
info() { printf '==> %s\n' "$*"; }

command -v jq >/dev/null 2>&1 || die "jq is required"

# --- arguments -------------------------------------------------------------
name="${1:-}"
[[ -n "$name" && "$name" != -* ]] || die "usage: template-forge-scaffold.sh <name> [options]"
shift

description="A reference template for the DarcStar marketplace."
author=""
components="commands"
from_plugin=""
register_root=""
out="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description) description="${2:?--description needs a value}" && shift 2 ;;
    --author) author="${2:?--author needs a value}" && shift 2 ;;
    --components) components="${2:?--components needs a value}" && shift 2 ;;
    --from-plugin) from_plugin="${2:?--from-plugin needs a value}" && shift 2 ;;
    --register) register_root="${2:?--register needs a repo root}" && shift 2 ;;
    --out) out="${2:?--out needs a value}" && shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] ||
  die "template name must be lowercase alphanumeric with hyphens (got '$name')"

# --- resolve destination ---------------------------------------------------
if [[ -n "$register_root" ]]; then
  [[ -d "$register_root" ]] || die "register root not found: $register_root"
  [[ -f "$register_root/.claude-plugin/marketplace.json" ]] ||
    die "register root is not a marketplace (no .claude-plugin/marketplace.json): $register_root"
  dest="$register_root/templates/$name"
else
  dest="$out/$name"
fi
[[ ! -e "$dest" ]] || die "destination already exists: $dest"

# Fail BEFORE writing anything if the release package is already registered, so a
# re-run can't half-create a template.
cfg="${register_root:+$register_root/release-please-config.json}"
if [[ -n "$register_root" && -f "$cfg" ]]; then
  jq -e --arg path "templates/$name" '.packages | has($path)' "$cfg" >/dev/null 2>&1 &&
    die "release-please-config.json already has a templates/$name package"
fi

# --- resolve --from-plugin source (if any) ---------------------------------
src_name=""
src_desc=""
if [[ -n "$from_plugin" ]]; then
  # Accept a path relative to CWD or, in register mode, to the repo root.
  if [[ -d "$from_plugin" ]]; then
    src_dir="$from_plugin"
  elif [[ -n "$register_root" && -d "$register_root/$from_plugin" ]]; then
    src_dir="$register_root/$from_plugin"
  else
    die "--from-plugin directory not found: $from_plugin"
  fi
  [[ -f "$src_dir/.claude-plugin/plugin.json" ]] ||
    die "--from-plugin is not a plugin (no .claude-plugin/plugin.json): $src_dir"
  src_name="$(jq -r '.name // empty' "$src_dir/.claude-plugin/plugin.json")"
  src_desc="$(jq -r '.description // empty' "$src_dir/.claude-plugin/plugin.json")"
  [[ -n "$src_name" ]] || die "--from-plugin plugin.json has no name: $src_dir"
fi

# --- scaffold --------------------------------------------------------------
mode="local"
[[ -n "$register_root" ]] && mode="marketplace"
src_note=""
[[ -n "$from_plugin" ]] && src_note=" from plugin '$src_name'"
info "scaffolding template $dest (mode: $mode)$src_note"
mkdir -p "$dest/.claude-plugin"

# Docs/manifest share these placeholders, rendered with the TEMPLATE's own
# identity (the template is itself a valid plugin named <name>).
render() {
  local c="$1"
  c="${c//\{\{NAME\}\}/$name}"
  c="${c//\{\{DESC\}\}/$description}"
  printf '%s\n' "$c"
}

if [[ -n "$from_plugin" ]]; then
  # from-plugin: copy the source plugin's component dirs, then reverse the source's
  # identity back to placeholders in every text (non-binary) file that mentions it.
  for comp in commands agents skills scripts; do
    [[ -d "$src_dir/$comp" ]] || continue
    cp -R "$src_dir/$comp" "$dest/$comp"
  done
  # Find every text file that mentions the source name or description, then reverse
  # both. Build grep args in an array so a multi-word description can't word-split.
  grep_args=(-rlZ -I -e "$src_name")
  [[ -n "$src_desc" ]] && grep_args+=(-e "$src_desc")
  while IFS= read -r -d '' f; do
    content="$(cat "$f")" # read fully before the redirect truncates the file
    # Replace the description FIRST: the name often occurs *within* the description,
    # so doing the name first would corrupt the (longer, more specific) desc match.
    [[ -n "$src_desc" ]] && content="${content//"$src_desc"/\{\{DESC\}\}}"
    content="${content//"$src_name"/\{\{NAME\}\}}"
    printf '%s' "$content" >"$f"
  done < <(grep "${grep_args[@]}" "$dest" 2>/dev/null || true)
else
  # default: empty component dirs for each requested type (commas or spaces).
  for comp in ${components//,/ }; do
    case "$comp" in
      commands | agents | skills | scripts) mkdir -p "$dest/$comp" ;;
      *) die "unknown component type: $comp (expected commands|agents|skills|scripts)" ;;
    esac
  done
fi

# Manifest: identity + 0.1.0 (a template's first release-please release is 0.1.0).
jq -n --arg name "$name" --arg desc "$description" --arg author "$author" \
  '{name: $name, version: "0.1.0", description: $desc}
   + (if $author == "" then {} else {author: {name: $author}} end)
   + {license: "MIT", keywords: []}' \
  >"$dest/.claude-plugin/plugin.json"

# Docs from inline scaffolds (a template needs valid docs to pass check-all.sh).
render "$(
  cat <<'EOF'
# {{NAME}}

{{DESC}}

Not published to the public catalog — this is a reference **template** the
marketplace scaffolder copies component directories from.

## Components

_List the component dirs this template contributes and what archetype they model.
Use `{{NAME}}`/`{{DESC}}` placeholders in components for anything that should become
the scaffolded plugin's identity._
EOF
)" >"$dest/README.md"

render "$(
  cat <<'EOF'
# {{NAME}} — Context

> Orientation for humans and AI assistants working on this template.

## Purpose

{{DESC}}

## Mental model

This is a **template**: an internal plugin under `templates/` whose component
directories (`commands/`, `agents/`, `skills/`, `scripts/`) the marketplace
scaffolder copies into new plugins, substituting `{{NAME}}`/`{{DESC}}`. It differs
from a published plugin only by living under `templates/` (never in
`marketplace.json`) — so keep the components archetype-shaped and generic.

## Challenging concepts & gotchas

_Document what this archetype is for and any placeholders/ordering the components
rely on._
EOF
)" >"$dest/CONTEXT.md"

render "$(
  cat <<'EOF'
# Changelog

All notable changes to the `{{NAME}}` template are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial scaffold of the `{{NAME}}` template.
EOF
)" >"$dest/CHANGELOG.md"

# --- register (marketplace mode only) --------------------------------------
if [[ -n "$register_root" ]]; then
  if [[ -f "$cfg" ]]; then
    tmp="$(mktemp)"
    jq --arg path "templates/$name" --arg comp "$name" \
      '.packages[$path] = {
          "release-type": "simple",
          "component": $comp,
          "changelog-path": "CHANGELOG.md",
          "exclude-paths": [
            ($path + "/README.md"),
            ($path + "/CONTEXT.md"),
            ($path + "/CHANGELOG.md")
          ],
          "extra-files": [
            {"type": "json", "path": ".claude-plugin/plugin.json", "jsonpath": "$.version"}
          ]
        }' "$cfg" >"$tmp" && mv "$tmp" "$cfg"
  else
    die "release-please-config.json not found in register root: $register_root"
  fi

  man="$register_root/.release-please-manifest.json"
  if [[ -f "$man" ]]; then
    tmp="$(mktemp)"
    # Seed at 0.0.0; the repo's release-please initial-version (0.1.0) makes the
    # first release a clean 0.1.0.
    jq --arg path "templates/$name" '.[$path] = "0.0.0"' "$man" >"$tmp" && mv "$tmp" "$man"
  else
    die ".release-please-manifest.json not found in register root: $register_root"
  fi
  info "registered template $name (release config + manifest; NOT marketplace.json)"
fi

info "done: $dest"
