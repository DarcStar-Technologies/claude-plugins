# Changelog

All notable changes to the `plan-confirm-apply` template are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plan-confirm-apply-v0.1.0...plan-confirm-apply--v0.2.0) (2026-07-17)


### Features

* **templates:** add a `template.json` manifest with cross-kind dependencies (part 1 of [#79](https://github.com/DarcStar-Technologies/claude-plugins/issues/79)) ([#80](https://github.com/DarcStar-Technologies/claude-plugins/issues/80)) ([8f762bb](https://github.com/DarcStar-Technologies/claude-plugins/commit/8f762bb0237759d66f120b087dd3b373999ef4a6))

## 0.1.0 (2026-07-16)


### Features

* **plan-confirm-apply:** add the plan-confirm-apply template ([#48](https://github.com/DarcStar-Technologies/claude-plugins/issues/48)) ([17524f1](https://github.com/DarcStar-Technologies/claude-plugins/commit/17524f15239a8b38433be5227ee59d16707269ff))

## [Unreleased]

### Added

- Initial `plan-confirm-apply` template: the plan→confirm→apply archetype — a guided
  `guided-change` command, a read-only `{{NAME}}-planner` subagent, and a
  `discover-targets.sh` discovery script. Distilled from the `plugin-editor` plugin.
