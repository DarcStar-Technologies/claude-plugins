# Changelog

All notable changes to the `dep-doctor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-07-17)


### Features

* **dep-doctor:** verify (and optionally install) a plugin's dependencies ([#66](https://github.com/DarcStar-Technologies/claude-plugins/issues/66)) ([5aae574](https://github.com/DarcStar-Technologies/claude-plugins/commit/5aae574e273e7de2968dd6890b0505600a237e73))

## [Unreleased]

### Added

- Initial `dep-doctor` plugin: a `/dep-doctor` command and read-only `dep-planner` agent
  that verify a target plugin's dependencies (CLI tools, libraries, MCP servers, other
  plugins) and, with explicit confirmation, install what's missing via a plan→confirm→apply
  flow. Deterministic scripts: `discover-plugins.sh` (picker), `check-deps.sh` (read-only
  classifier), and `apply-remediation.sh` (allow-listed, confirmation-gated installer that
  refuses `sudo`/system package managers/plugin installs and surfaces them as manual
  steps). Built on the `plan-confirm-apply` template.
