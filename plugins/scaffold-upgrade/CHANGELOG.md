# Changelog

All notable changes to the `scaffold-upgrade` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `/scaffold-upgrade` command and `scripts/check-upgrade.sh`: report whether a
  plugin scaffolded from a template is behind the latest version of that template —
  the semver gap and what changed — read-only. Resolves the latest template version
  from an ancestor marketplace, a local path, or the template's `<name>-v*` release
  tags, and reuses the `semver` engine (resolved at run time, not vendored).
