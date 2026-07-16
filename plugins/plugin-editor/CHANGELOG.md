# Changelog

All notable changes to the `plugin-editor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- /edit-plugin command + edit-planner agent: guided plan->confirm->apply modification of an existing plugin, with template checks (check-template.sh), a changelog entry (update-changelog.sh), context-aware versioning (sync-version.sh), and an install/reload hint (check-install-status.sh).
