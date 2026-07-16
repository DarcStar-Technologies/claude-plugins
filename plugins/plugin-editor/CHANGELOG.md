# Changelog

All notable changes to the `plugin-editor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.3.0...plugin-editor-v0.4.0) (2026-07-16)


### Features

* **plugin-editor:** add --dry-run flag to preview the plan without applying ([#30](https://github.com/DarcStar-Technologies/claude-plugins/issues/30)) ([6da2e50](https://github.com/DarcStar-Technologies/claude-plugins/commit/6da2e50f872026e7559548f858bb377815d51a8a))

## [0.3.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.2.0...plugin-editor-v0.3.0) (2026-07-16)


### Features

* **plugin-editor:** scope check-template.sh to the target plugin only ([#25](https://github.com/DarcStar-Technologies/claude-plugins/issues/25)) ([aa43933](https://github.com/DarcStar-Technologies/claude-plugins/commit/aa4393315db255dc82fecc57ecaeb49b83167da2)), closes [#24](https://github.com/DarcStar-Technologies/claude-plugins/issues/24)

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.1.0...plugin-editor-v0.2.0) (2026-07-16)


### Features

* **plugin-editor:** plugin picker, post-edit verify, and change summary ([#22](https://github.com/DarcStar-Technologies/claude-plugins/issues/22)) ([d476d79](https://github.com/DarcStar-Technologies/claude-plugins/commit/d476d796f566903d99dc4fbb9fa3cd940cd80405)), closes [#21](https://github.com/DarcStar-Technologies/claude-plugins/issues/21)

## 0.1.0 (2026-07-16)


### Features

* **plugin-editor:** guided assistant to modify an existing plugin ([#19](https://github.com/DarcStar-Technologies/claude-plugins/issues/19)) ([fde6c16](https://github.com/DarcStar-Technologies/claude-plugins/commit/fde6c162ef3a88e0699ea0f7086efca5bd604d0e)), closes [#18](https://github.com/DarcStar-Technologies/claude-plugins/issues/18)

## [Unreleased]

### Changed

- check-template.sh now validates only the target plugin (manifest fields, semver version, name/dir, docs, changelog structure, and scripts) instead of running check-all across the whole repository.

### Added

- /edit-plugin now runs guided intake when the change is not fully described up front — asking the change type, then plugin-specific suggestions (with a free-form option) — and adds `--plugin=<dir>` / `--type=add|change|fix|remove` flags so it resumes from whatever is already known instead of re-asking.
- Added a `--dry-run` flag to `/edit-plugin` that previews the plan (files, changelog entry, version impact) without applying any edits or running the changelog/version/reload scripts.
- /edit-plugin now lists the marketplace's plugins to pick from when no target directory is given, verifies every planned edit actually landed before reporting, and ends with a clear summary of files changed, the changelog entry, and the version outcome.
- /edit-plugin command + edit-planner agent: guided plan->confirm->apply modification of an existing plugin, with template checks (check-template.sh), a changelog entry (update-changelog.sh), context-aware versioning (sync-version.sh), and an install/reload hint (check-install-status.sh).
