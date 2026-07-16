# Changelog

All notable changes to the `semver` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/semver-v0.1.0...semver-v0.2.0) (2026-07-16)


### Features

* **templates:** support multiple named templates under templates/ ([#13](https://github.com/DarcStar-Technologies/claude-plugins/issues/13)) ([afb499c](https://github.com/DarcStar-Technologies/claude-plugins/commit/afb499cc3db618e22d66f99f05b281fe36c0ece9)), closes [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)

## 0.1.0 (2026-07-16)


### Features

* **semver:** add semver plugin and reuse its engine in scaffold-report ([#11](https://github.com/DarcStar-Technologies/claude-plugins/issues/11)) ([3a5df97](https://github.com/DarcStar-Technologies/claude-plugins/commit/3a5df975a8a059dc3b4890e2bec7b148bbf126f8)), closes [#10](https://github.com/DarcStar-Technologies/claude-plugins/issues/10)

## [Unreleased]

### Added

- `/semver` command and `scripts/semver.sh`: deterministic Semantic Versioning
  operations — `validate`, `compare` (full semver.org precedence), `bump`,
  `major`/`minor`/`patch`, `diff`, and `next` (from Conventional Commits).
- The repo's `scaffold-report.sh` reuses this engine for template-drift
  comparison (single source of truth for version math).
