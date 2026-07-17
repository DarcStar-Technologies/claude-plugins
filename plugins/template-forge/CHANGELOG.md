# Changelog

All notable changes to the `template-forge` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/template-forge-v0.1.0...template-forge--v0.2.0) (2026-07-17)


### Features

* **templates:** add a `template.json` manifest with cross-kind dependencies (part 1 of [#79](https://github.com/DarcStar-Technologies/claude-plugins/issues/79)) ([#80](https://github.com/DarcStar-Technologies/claude-plugins/issues/80)) ([8f762bb](https://github.com/DarcStar-Technologies/claude-plugins/commit/8f762bb0237759d66f120b087dd3b373999ef4a6))

## 0.1.0 (2026-07-16)


### Features

* **template-forge:** scaffold a new reference template from a description, prompts, or a plugin ([#45](https://github.com/DarcStar-Technologies/claude-plugins/issues/45)) ([e2e2bea](https://github.com/DarcStar-Technologies/claude-plugins/commit/e2e2bea860bbd1213aef8db59c2b6602152d28ff))

## [Unreleased]

### Added

- Initial `template-forge` plugin: a `/forge-template` command, a read-only
  `template-planner` agent, and a deterministic `template-forge-scaffold.sh` that
  creates a new reference template under `templates/` from a description, guided
  prompts, or an existing plugin (`--from-plugin`, reverse-substituting the plugin's
  name/description back to `{{NAME}}`/`{{DESC}}`). Registers the template for
  release management but never in `marketplace.json`.
