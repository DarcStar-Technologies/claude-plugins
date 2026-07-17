# Changelog

All notable changes to the `scaffold-retarget` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-07-17)


### Features

* **scaffold-retarget:** plugin to upgrade/downgrade a plugin's template version ([#87](https://github.com/DarcStar-Technologies/claude-plugins/issues/87)) ([970d06f](https://github.com/DarcStar-Technologies/claude-plugins/commit/970d06fafcbad33eaba0cfe7b3003526339301ce))

## [Unreleased]

### Added

- Initial `scaffold-retarget` plugin: a `/scaffold-retarget` command and read-only
  `scaffold-retarget-planner` agent that **upgrade or downgrade** an already-scaffolded
  plugin to a different version of its source template, via a plan→confirm→apply flow —
  the mutating companion to the read-only `scaffold-upgrade`. Deterministic scripts:
  `discover-targets.sh` (picker over provenance-carrying plugins),
  `resolve-template-version.sh` (materialize an arbitrary template version from an
  ancestor marketplace / local path / `--v`+`-v` release tags, reusing the `semver`
  engine), `diff-components.sh` (a 3-way base/current/target classification that renders
  the template's `{{NAME}}`/`{{DESC}}` with the plugin's own identity before comparing),
  and `apply-retarget.sh` (applies the approved per-file decisions, updates
  `scaffold.json`'s `templateVersion`, and records a CHANGELOG entry — inside the plugin
  dir only, never touching its `plugin.json` identity). Declares a versioned dependency on
  the `semver` plugin. Built on the `plan-confirm-apply` template.
