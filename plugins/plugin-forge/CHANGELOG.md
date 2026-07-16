# Changelog

All notable changes to the `plugin-forge` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Entries below `[Unreleased]` are generated automatically from
[Conventional Commits](https://www.conventionalcommits.org/) by release-please.

## 0.1.0 (2026-07-16)


### Features

* **plugin-forge:** AI-assisted plugin scaffolder ([#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)) ([#3](https://github.com/DarcStar-Technologies/claude-plugins/issues/3)) ([248baa1](https://github.com/DarcStar-Technologies/claude-plugins/commit/248baa10d3c7a2e9b31820c08d979093f79afbdb))

## [Unreleased]

### Added

- Portable mode: `scripts/forge-scaffold.sh` scaffolds a standalone plugin in any
  project (registering nothing), resolving the template from a `_template-v*`
  version tag, a repo, a local `./_template/`, or the latest from this repo.
  `/forge` now auto-detects marketplace vs portable mode. Implements #5.
- `/forge` command and the `plugin-planner` agent: scaffold a new marketplace
  plugin from a natural-language description, prompting for anything that can't be
  inferred. Delegates the deterministic work to `scripts/new-plugin.sh`.
