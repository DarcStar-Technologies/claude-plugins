# Changelog

All notable changes to the `command-suite` reference template are documented in
this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-07-16)


### Features

* **templates:** support multiple named templates under templates/ ([#13](https://github.com/DarcStar-Technologies/claude-plugins/issues/13)) ([afb499c](https://github.com/DarcStar-Technologies/claude-plugins/commit/afb499cc3db618e22d66f99f05b281fe36c0ece9)), closes [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)

## [Unreleased]

### Added

- Reference template for the command-suite archetype: several slash commands
  (`/upper`, `/count`) backed by one shared deterministic dispatcher
  (`scripts/suite.sh`).
- Plugin documentation set: `CONTEXT.md`, `README.md`, `CHANGELOG.md`.
