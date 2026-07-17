# Changelog

All notable changes to the `plugin-forge` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Entries below `[Unreleased]` are generated automatically from
[Conventional Commits](https://www.conventionalcommits.org/) by release-please.

## [0.6.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-forge-v0.5.0...plugin-forge--v0.6.0) (2026-07-17)


### Features

* **release:** tag releases as `{name}--v{version}` (part 1 of [#74](https://github.com/DarcStar-Technologies/claude-plugins/issues/74)) ([#75](https://github.com/DarcStar-Technologies/claude-plugins/issues/75)) ([fab0456](https://github.com/DarcStar-Technologies/claude-plugins/commit/fab045661f3ecd5ff60d6e6ffa653d6230aa5346))

## [0.5.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-forge-v0.4.0...plugin-forge-v0.5.0) (2026-07-17)


### Features

* **plugin-forge:** ask the template first in /forge guided intake ([#63](https://github.com/DarcStar-Technologies/claude-plugins/issues/63)) ([661bf84](https://github.com/DarcStar-Technologies/claude-plugins/commit/661bf84732bf961f47d22fccbd187f7334a030f6))

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

### Added

- `forge-scaffold.sh` now **propagates a template's declared dependencies** (from its
  `template.json`) into every scaffolded plugin: `kind:"plugin"` deps become the new
  `plugin.json` `dependencies` (bare string or `{name, version}`), and `cli`/`library`/`mcp`
  deps are documented in a "Dependencies" section of the new `CONTEXT.md` (those kinds have
  no manifest field). A template with no `template.json` propagates nothing.

### Changed

- `/forge`'s no-description guided intake now asks which **template** to use **first** (grounded in the real reference templates, carried forward as the authoritative `--template`), then the plugin's purpose, then concrete component-set suggestions — previously it asked the purpose first. The given-description flow is unchanged.

### Added

- Named-template selection: `/forge` and the `plugin-planner` agent choose among
  the marketplace's reference templates (the plugins under `templates/`) and pass
  `--template <name>` (default `default`) to the scaffolder. The planner returns a
  `template` field in its plan; templates are discovered via
  `scripts/list-templates.sh`. Part of #6.
