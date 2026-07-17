# Changelog

All notable changes to the `default` reference template are documented in this
file. (Entries tagged `_template-v*` predate its move to `templates/default`.)

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/default-v0.3.0...default--v0.4.0) (2026-07-17)


### Features

* **templates:** add a `template.json` manifest with cross-kind dependencies (part 1 of [#79](https://github.com/DarcStar-Technologies/claude-plugins/issues/79)) ([#80](https://github.com/DarcStar-Technologies/claude-plugins/issues/80)) ([8f762bb](https://github.com/DarcStar-Technologies/claude-plugins/commit/8f762bb0237759d66f120b087dd3b373999ef4a6))

## [0.3.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/default-v0.2.0...default-v0.3.0) (2026-07-16)


### Features

* **templates:** support multiple named templates under templates/ ([#13](https://github.com/DarcStar-Technologies/claude-plugins/issues/13)) ([afb499c](https://github.com/DarcStar-Technologies/claude-plugins/commit/afb499cc3db618e22d66f99f05b281fe36c0ece9)), closes [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/_template-v0.1.0..._template-v0.2.0) (2026-07-16)


### Features

* **plugin-forge:** portable mode — scaffold plugins outside this repo ([#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)) ([#7](https://github.com/DarcStar-Technologies/claude-plugins/issues/7)) ([60c96d1](https://github.com/DarcStar-Technologies/claude-plugins/commit/60c96d19a819b7a5ed63560ba1e07d5981a4c6a9))

## 0.1.0 (2026-07-16)


### Features

* **plugin-forge:** AI-assisted plugin scaffolder ([#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)) ([#3](https://github.com/DarcStar-Technologies/claude-plugins/issues/3)) ([248baa1](https://github.com/DarcStar-Technologies/claude-plugins/commit/248baa10d3c7a2e9b31820c08d979093f79afbdb))
* scaffold DarcStar plugin marketplace foundation ([3566a1d](https://github.com/DarcStar-Technologies/claude-plugins/commit/3566a1d6efee59286c2d1342c2ef734a90fbc02d))

## [Unreleased]

### Added

- Reference slash command (`/hello`) wired to a mechanized shell script.
- Reference subagent (`example-reviewer`) demonstrating minimum-model selection.
- Reference skill (`example-skill`).
- Plugin documentation set: `CONTEXT.md`, `README.md`, `CHANGELOG.md`.
