# Changelog

All notable changes to the `edit-kit` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial `edit-kit` provider plugin: the shared, deterministic edit-flow toolkit
  (`check-structure.sh`, `update-changelog.sh`, `sync-version.sh`, `scaffold-test.sh`,
  `verify-repo.sh`, `lib/plan-paths.sh`) that `plugin-editor` and `template-editor`
  resolve at run time (`$EDIT_KIT_DIR` → marketplace ancestor → `PATH`) instead of
  vendoring their own copies. No user command — a provider plugin, like `semver`.
