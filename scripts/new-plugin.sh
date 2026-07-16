#!/usr/bin/env bash
# Scaffold a new plugin and register it everywhere it needs to be registered.
#
# Usage:
#   scripts/new-plugin.sh <plugin-name> [--description "..."] [--author "..."]
#                         [--template <name>]
#
# It renders the templates/ files, copies the reference components from the
# chosen template (default: _template), records scaffold provenance, and updates
# the marketplace catalog and release-please configuration via jq. Run
# scripts/check-all.sh afterwards.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

require_cmd jq

name="${1:-}"
[[ -n "$name" && "$name" != -* ]] ||
  die "usage: new-plugin.sh <plugin-name> [--description \"...\"] [--author \"...\"] [--template <name>]"
shift

description="A DarcStar Technologies plugin."
author="DarcStar Technologies"
template="_template"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --description)
      description="${2:?--description needs a value}"
      shift 2
      ;;
    --author)
      author="${2:?--author needs a value}"
      shift 2
      ;;
    --template)
      template="${2:?--template needs a value}"
      shift 2
      ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] ||
  die "plugin name must be lowercase alphanumeric with hyphens (got '$name')"

root="$(repo_root)"
dest="$root/plugins/$name"
templates="$root/templates"
[[ ! -e "$dest" ]] || die "plugin already exists: plugins/$name"
[[ -d "$templates" ]] || die "missing templates/ directory"

template_dir="$root/plugins/$template"
template_manifest="$template_dir/.claude-plugin/plugin.json"
[[ -d "$template_dir" ]] || die "unknown template: plugins/$template"
[[ -f "$template_manifest" ]] || die "template '$template' has no plugin.json"
template_version="$(jq -r '.version // "unknown"' "$template_manifest")"

today="$(date +%Y-%m-%d)"
year="$(date +%Y)"
version="0.1.0"

# Render a token-substituted template file to a destination path.
render() {
  local src="$1" out="$2" content
  content="$(cat "$src")"
  content="${content//\{\{PLUGIN_NAME\}\}/$name}"
  content="${content//\{\{PLUGIN_DESCRIPTION\}\}/$description}"
  content="${content//\{\{PLUGIN_VERSION\}\}/$version}"
  content="${content//\{\{AUTHOR\}\}/$author}"
  content="${content//\{\{DATE\}\}/$today}"
  content="${content//\{\{YEAR\}\}/$year}"
  mkdir -p "$(dirname "$out")"
  printf '%s\n' "$content" >"$out"
}

info "scaffolding plugins/$name"
render "$templates/plugin.json.tmpl" "$dest/.claude-plugin/plugin.json"
render "$templates/CHANGELOG.md.tmpl" "$dest/CHANGELOG.md"
render "$templates/CONTEXT.md.tmpl" "$dest/CONTEXT.md"
render "$templates/README.md.tmpl" "$dest/README.md"

# Copy example components from the chosen template, then rename the template
# identifier inside the copied files.
for comp in commands agents skills scripts; do
  [[ -d "$template_dir/$comp" ]] || continue
  cp -r "$template_dir/$comp" "$dest/$comp"
done
while IFS= read -r -d '' f; do
  content="$(cat "$f")"
  content="${content//"$template"/$name}"
  printf '%s' "$content" >"$f"
done < <(grep -rlZ -F --binary-files=without-match "$template" "$dest" 2>/dev/null || true)

# Record scaffold provenance so a plugin can always be traced to the template
# (and template version) it was generated from. Written after the rename so the
# recorded template name is not itself rewritten.
jq -n \
  --arg template "$template" \
  --arg tver "$template_version" \
  --arg date "$today" \
  '{template: $template, templateVersion: $tver, scaffoldedWith: "scripts/new-plugin.sh", scaffoldedAt: $date}' \
  >"$dest/.claude-plugin/scaffold.json"
info "recorded provenance: template '$template' @ $template_version"

# Register in the marketplace catalog.
mp="$root/.claude-plugin/marketplace.json"
tmp="$(mktemp)"
# No version field here: plugin.json is the source of truth. release-please
# updates plugin.json, not the catalog, so a version here would silently drift.
jq --arg name "$name" --arg src "./plugins/$name" --arg desc "$description" \
  '.plugins += [{name: $name, source: $src, description: $desc}]' \
  "$mp" >"$tmp" && mv "$tmp" "$mp"
info "registered in marketplace.json"

# Register in release-please config + manifest.
cfg="$root/release-please-config.json"
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

man="$root/.release-please-manifest.json"
tmp="$(mktemp)"
# Seed the last-released version at 0.0.0 (nothing released yet) so release-please
# cuts a clean 0.1.0 as the plugin's first release. plugin.json keeps 0.1.0 as the
# in-development version.
jq --arg path "plugins/$name" '.[$path] = "0.0.0"' "$man" >"$tmp" && mv "$tmp" "$man"
info "registered in release automation"

info "done — next steps:"
printf '  1. Edit plugins/%s/CONTEXT.md and README.md\n' "$name"
printf '  2. Build commands/, agents/, skills/, scripts/ under plugins/%s/\n' "$name"
printf '  3. Run: scripts/check-all.sh\n'
