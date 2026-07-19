# Changelog

All notable changes to the `scaffold-retarget` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1](https://github.com/DarcStar-Technologies/claude-plugins/compare/scaffold-retarget--v0.2.0...scaffold-retarget--v0.2.1) (2026-07-18)


### Bug Fixes

* **plan-confirm-apply:** backport the hardened plan-kit gate to earlier consumers ([#105](https://github.com/DarcStar-Technologies/claude-plugins/issues/105)) ([53aa0d0](https://github.com/DarcStar-Technologies/claude-plugins/commit/53aa0d025c61f08cd0b66c96aa62d2dfa2c28d85))

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/scaffold-retarget--v0.1.0...scaffold-retarget--v0.2.0) (2026-07-18)


### Features

* **scaffold-retarget:** validate plans via the shared plan-kit provider ([#99](https://github.com/DarcStar-Technologies/claude-plugins/issues/99)) ([2e9ff34](https://github.com/DarcStar-Technologies/claude-plugins/commit/2e9ff34c6432df5a6c47c8c4c7180944582512af))

## 0.1.0 (2026-07-17)


### Features

* **scaffold-retarget:** plugin to upgrade/downgrade a plugin's template version ([#87](https://github.com/DarcStar-Technologies/claude-plugins/issues/87)) ([970d06f](https://github.com/DarcStar-Technologies/claude-plugins/commit/970d06fafcbad33eaba0cfe7b3003526339301ce))

## [Unreleased]

### Changed

- Replaced the vendored plan-kit-path.sh resolver with the generic provider-path.sh (`provider-path.sh plan-kit validate-plan.sh`). Behavior unchanged.
- The plan-kit validation gate is hardened: validation is advisory under --dry-run (an unresolvable plan-kit or a failing plan still shows the preview, since a dry run mutates nothing), and a malformed-JSON error (the command failing to strip the planner's code fence) is re-extracted locally rather than blamed on the planner and burning retries.
- Retargeted provenance to plan-confirm-apply template v0.4.0 — the version that moved plan-shape validation into the shared plan-kit provider — so scaffold-retarget adopts that shared validator instead of relying on a vendored check.

### Added

- The plan step now validates the planner's JSON plan via the shared plan-kit provider — scripts/provider-path.sh resolves plan-kit and the command runs validate-plan.sh --actions add,keep,update,delete before the confirm gate. Adds a plan-kit >=0.1.0 dependency in plugin.json (Claude Code auto-installs it).
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
