# Changelog

All notable changes to the `plugin-editor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.8.0...plugin-editor-v0.9.0) (2026-07-17)


### Features

* **deps:** declare first-class plugin dependencies in plugin.json ([#69](https://github.com/DarcStar-Technologies/claude-plugins/issues/69)) ([aa1966d](https://github.com/DarcStar-Technologies/claude-plugins/commit/aa1966de21a59eb8bf943ee552b1f435fb6a7270))

## [0.8.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.7.0...plugin-editor-v0.8.0) (2026-07-17)


### Features

* **plugin-editor:** consume the shared edit-kit toolkit (complete the DRY arc) ([#60](https://github.com/DarcStar-Technologies/claude-plugins/issues/60)) ([209c2e4](https://github.com/DarcStar-Technologies/claude-plugins/commit/209c2e424a7f7d9d54be5d60cfd7673263872b92))

## [0.7.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.6.0...plugin-editor-v0.7.0) (2026-07-16)


### Features

* **plugin-editor:** auto-scaffold a bundled bats stub for new scripts ([#42](https://github.com/DarcStar-Technologies/claude-plugins/issues/42)) ([0017b1c](https://github.com/DarcStar-Technologies/claude-plugins/commit/0017b1c84c7aba30aeebefb44a53b8fb303b5b95))

## [0.6.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.5.0...plugin-editor-v0.6.0) (2026-07-16)


### Features

* **plugin-editor:** post-apply repo verification in /edit-plugin ([#39](https://github.com/DarcStar-Technologies/claude-plugins/issues/39)) ([1c0041f](https://github.com/DarcStar-Technologies/claude-plugins/commit/1c0041f8a372a77ca93e87326dd7361db570926a))

## [0.5.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plugin-editor-v0.4.0...plugin-editor-v0.5.0) (2026-07-16)


### Features

* **plugin-editor:** guided intake when the change isn't fully described ([#36](https://github.com/DarcStar-Technologies/claude-plugins/issues/36)) ([60973e1](https://github.com/DarcStar-Technologies/claude-plugins/commit/60973e1a7e97f1e0dd0038bd3da02b1c9bcf9f66))

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

- Declare a bare-string dependency on the `edit-kit` plugin in `plugin.json`, so Claude Code auto-installs it (and transitively `semver`) instead of the edit flow only discovering it missing at run time. Bare-string (no version range) because versioned dependencies resolve against `<name>--v` git tags, which this repo's single-hyphen release-please tags do not produce.
- Reuse the shared `edit-kit` toolkit: the generic edit-flow scripts (changelog, versioning, structure check, repo verification, test-stub scaffolding) now resolve from the `edit-kit` provider plugin at run time instead of being vendored here; `check-template.sh` delegates structure to edit-kit's `check-structure.sh` and keeps only the template-drift check. Adds a runtime dependency on the `edit-kit` plugin.
- check-template.sh now validates only the target plugin (manifest fields, semver version, name/dir, docs, changelog structure, and scripts) instead of running check-all across the whole repository.

### Added

- Auto-scaffold a bundled `scripts/tests/<name>.bats` stub (via new `scripts/scaffold-test.sh`) for every new `scripts/*.sh` an approved plan creates — a skipped placeholder that gives the new script a bundled test to flesh out (it does not auto-run the script), discovered by `verify-repo.sh`. Idempotent; writes only inside the target plugin's own directory.
- Add a post-apply cross-check pass (`verify-repo.sh`) to `/edit-plugin`: runs the marketplace's `check-all.sh` and the plugin's `bats` tests. Scoped and advisory — it hard-fails only on the plugin's own bundled tests (in-bounds to fix); repo-wide and centralized-test failures are surfaced as warnings rather than blocking a correct isolated edit (skips cleanly outside a marketplace repo).
- /edit-plugin now runs guided intake when the change is not fully described up front — asking the change type, then plugin-specific suggestions (with a free-form option) — and adds `--plugin=<dir>` / `--type=add|change|fix|remove` flags so it resumes from whatever is already known instead of re-asking.
- Added a `--dry-run` flag to `/edit-plugin` that previews the plan (files, changelog entry, version impact) without applying any edits or running the changelog/version/reload scripts.
- /edit-plugin now lists the marketplace's plugins to pick from when no target directory is given, verifies every planned edit actually landed before reporting, and ends with a clear summary of files changed, the changelog entry, and the version outcome.
- /edit-plugin command + edit-planner agent: guided plan->confirm->apply modification of an existing plugin, with template checks (check-template.sh), a changelog entry (update-changelog.sh), context-aware versioning (sync-version.sh), and an install/reload hint (check-install-status.sh).
