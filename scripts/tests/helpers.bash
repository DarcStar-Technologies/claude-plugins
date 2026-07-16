#!/usr/bin/env bash
# Shared setup for the bats test suite. Builds a throwaway fixture repository
# so the scripts run in isolation from the real working tree. The scripts derive
# the repo root from their own location, so copying scripts/ into the fixture is
# enough to redirect them.

fixture_scripts_dir() {
  cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd
}

repo_root_dir() {
  cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd
}

setup_fixture() {
  FIX="$(mktemp -d)"
  cp -r "$(fixture_scripts_dir)" "$FIX/scripts"
  mkdir -p "$FIX/.claude-plugin"
  cat >"$FIX/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "test",
  "owner": { "name": "test" },
  "plugins": []
}
JSON
}

# A fuller fixture that mirrors a marketplace repo (validators, the _template
# reference, and empty manifests) so integration tests can scaffold + register
# end to end. It copies ONLY _template, not real published plugins, so these
# tests stay isolated as the marketplace grows.
setup_full_fixture() {
  FIX="$(mktemp -d)"
  local r
  r="$(repo_root_dir)"
  cp -r "$r/scripts" "$FIX/scripts"
  mkdir -p "$FIX/plugins"
  cp -r "$r/plugins/_template" "$FIX/plugins/_template"
  mkdir -p "$FIX/.claude-plugin"
  printf '{ "name": "test", "owner": { "name": "test" }, "plugins": [] }\n' \
    >"$FIX/.claude-plugin/marketplace.json"
  printf '{ "packages": {} }\n' >"$FIX/release-please-config.json"
  printf '{}\n' >"$FIX/.release-please-manifest.json"
}

# Scaffold + register a plugin into the fixture marketplace (marketplace mode),
# using the real plugin-forge scaffolder pointed at the fixture root.
fixture_scaffold() {
  "$(repo_root_dir)/plugins/plugin-forge/scripts/forge-scaffold.sh" "$@" --register "$FIX"
}

teardown_fixture() {
  [[ -n "${FIX:-}" ]] && rm -rf "$FIX"
}

# add_plugin <name> <version> [--no-changelog] [--no-context]
add_plugin() {
  local name="$1" version="$2"
  shift 2
  local no_changelog=0 no_context=0 no_scaffold=0
  for a in "$@"; do
    case "$a" in
      --no-changelog) no_changelog=1 ;;
      --no-context) no_context=1 ;;
      --no-scaffold) no_scaffold=1 ;;
    esac
  done

  local d="$FIX/plugins/$name"
  mkdir -p "$d/.claude-plugin"
  cat >"$d/.claude-plugin/plugin.json" <<JSON
{ "name": "$name", "version": "$version", "description": "test plugin" }
JSON

  if [[ "$no_changelog" -eq 0 ]]; then
    cat >"$d/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]
MD
  fi
  [[ "$no_context" -eq 0 ]] && : >"$d/CONTEXT.md"
  : >"$d/README.md"

  # Register non-internal plugins in the marketplace and give them scaffold
  # provenance so validation passes (unless a test opts out).
  if [[ "$name" != _* ]]; then
    local mp="$FIX/.claude-plugin/marketplace.json" tmp
    tmp="$(mktemp)"
    jq --arg n "$name" --arg s "./plugins/$name" \
      '.plugins += [{name: $n, source: $s}]' "$mp" >"$tmp" && mv "$tmp" "$mp"

    if [[ "$no_scaffold" -eq 0 ]]; then
      cat >"$d/.claude-plugin/scaffold.json" <<'JSON'
{ "template": "_template", "templateVersion": "0.1.0", "scaffoldedWith": "test", "scaffoldedAt": "2026-01-01" }
JSON
    fi
  fi
}
