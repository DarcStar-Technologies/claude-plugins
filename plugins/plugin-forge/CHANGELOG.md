# Changelog

All notable changes to the `plugin-forge` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Entries below `[Unreleased]` are generated automatically from
[Conventional Commits](https://www.conventionalcommits.org/) by release-please.

## [0.4.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-forge-v0.3.0...plugin-forge-v0.4.0) (2026-07-16)


### Features

* **plugin-forge:** guided intake when /forge has no description ([#51](https://github.com/DarcStar-Technologies/claude-plugins/issues/51)) ([299ae7b](https://github.com/DarcStar-Technologies/claude-plugins/commit/299ae7ba9ae472101769f58d90ce06a24277d2be))

## [0.3.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-forge-v0.2.0...plugin-forge-v0.3.0) (2026-07-16)


### Features

* **templates:** support multiple named templates under templates/ ([#13](https://github.com/DarcStar-Technologies/claude-plugins/issues/13)) ([afb499c](https://github.com/DarcStar-Technologies/claude-plugins/commit/afb499cc3db618e22d66f99f05b281fe36c0ece9)), closes [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-forge-v0.1.0...plugin-forge-v0.2.0) (2026-07-16)


### Features

* **plugin-forge:** portable mode — scaffold plugins outside this repo ([#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)) ([#7](https://github.com/DarcStar-Technologies/claude-plugins/issues/7)) ([60c96d1](https://github.com/DarcStar-Technologies/claude-plugins/commit/60c96d19a819b7a5ed63560ba1e07d5981a4c6a9))

## 0.1.0 (2026-07-16)


### Features

* **plugin-forge:** AI-assisted plugin scaffolder ([#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)) ([#3](https://github.com/DarcStar-Technologies/claude-plugins/issues/3)) ([248baa1](https://github.com/DarcStar-Technologies/claude-plugins/commit/248baa10d3c7a2e9b31820c08d979093f79afbdb))

## [Unreleased]

### Changed

- `/forge` invoked with no description now runs a guided intake instead of a bare free-text ask: it captures the plugin's purpose, then refines the shape via `AskUserQuestion` (the kind of plugin — grounded in the real reference templates and carried forward as the authoritative `--template` — then concrete component-set suggestions). The given-description flow is unchanged.

### Added

- Named-template selection: `/forge` and the `plugin-planner` agent choose among
  the marketplace's reference templates (the plugins under `templates/`) and pass
  `--template <name>` (default `default`) to the scaffolder. The planner returns a
  `template` field in its plan; templates are discovered via
  `scripts/list-templates.sh`. Part of #6.
