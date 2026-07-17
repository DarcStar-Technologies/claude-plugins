# Changelog

All notable changes to the `scaffold-upgrade` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-07-16)


### Features

* **scaffold-upgrade:** report whether a plugin is behind its source template ([#16](https://github.com/DarcStar-Technologies/claude-plugins/issues/16)) ([2687d60](https://github.com/DarcStar-Technologies/claude-plugins/commit/2687d6083fe7d1b324d4e8b7178a89481c68aa01)), closes [#15](https://github.com/DarcStar-Technologies/claude-plugins/issues/15)

## [Unreleased]

### Changed

- Declare a bare-string dependency on the `semver` plugin in `plugin.json` (its version math reuses the semver engine).

### Added

- `/scaffold-upgrade` command and `scripts/check-upgrade.sh`: report whether a
  plugin scaffolded from a template is behind the latest version of that template —
  the semver gap and what changed — read-only. Resolves the latest template version
  from an ancestor marketplace, a local path, or the template's `<name>-v*` release
  tags, and reuses the `semver` engine (resolved at run time, not vendored).
