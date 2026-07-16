# Changelog

All notable changes to the `plugin-forge` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Entries below `[Unreleased]` are generated automatically from
[Conventional Commits](https://www.conventionalcommits.org/) by release-please.

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-forge-v0.1.0...plugin-forge-v0.2.0) (2026-07-16)


### Features

* **plugin-forge:** portable mode — scaffold plugins outside this repo ([#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)) ([#7](https://github.com/DarcStar-Technologies/claude-plugins/issues/7)) ([60c96d1](https://github.com/DarcStar-Technologies/claude-plugins/commit/60c96d19a819b7a5ed63560ba1e07d5981a4c6a9))

## 0.1.0 (2026-07-16)


### Features

* **plugin-forge:** AI-assisted plugin scaffolder ([#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)) ([#3](https://github.com/DarcStar-Technologies/claude-plugins/issues/3)) ([248baa1](https://github.com/DarcStar-Technologies/claude-plugins/commit/248baa10d3c7a2e9b31820c08d979093f79afbdb))

## [Unreleased]

### Added

- Portable mode + unified scaffolder: `scripts/forge-scaffold.sh` is now the single
  scaffolding engine (replacing the marketplace-only `scripts/new-plugin.sh`). It
  scaffolds a standalone plugin anywhere, or registers into a marketplace with
  `--register <root>`, resolving the template from a `<template>-v*` version tag, a
  repo, a local `./<template>/`, or the latest from this repo. `/forge` auto-detects
  the mode. Implements #5.
- `/forge` command and the `plugin-planner` agent: scaffold a new marketplace
  plugin from a natural-language description, prompting for anything that can't be
  inferred. Delegates the deterministic work to `scripts/forge-scaffold.sh`.
