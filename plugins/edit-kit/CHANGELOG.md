# Changelog

All notable changes to the `edit-kit` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-07-17)


### Features

* **edit-kit:** add shared edit-flow toolkit (provider plugin) ([#54](https://github.com/DarcStar-Technologies/claude-plugins/issues/54)) ([45883b3](https://github.com/DarcStar-Technologies/claude-plugins/commit/45883b36c31ada2b359dc1e9d5c0d50e3f907531))

## [Unreleased]

### Added

- Initial `edit-kit` provider plugin: the shared, deterministic edit-flow toolkit
  (`check-structure.sh`, `update-changelog.sh`, `sync-version.sh`, `scaffold-test.sh`,
  `verify-repo.sh`, `lib/plan-paths.sh`) that `plugin-editor` and `template-editor`
  resolve at run time (`$EDIT_KIT_DIR` → marketplace ancestor → `PATH`) instead of
  vendoring their own copies. No user command — a provider plugin, like `semver`.
