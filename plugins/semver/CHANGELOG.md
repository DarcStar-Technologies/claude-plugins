# Changelog

All notable changes to the `semver` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `/semver` command and `scripts/semver.sh`: deterministic Semantic Versioning
  operations — `validate`, `compare` (full semver.org precedence), `bump`,
  `major`/`minor`/`patch`, `diff`, and `next` (from Conventional Commits).
- The repo's `scaffold-report.sh` reuses this engine for template-drift
  comparison (single source of truth for version math).
