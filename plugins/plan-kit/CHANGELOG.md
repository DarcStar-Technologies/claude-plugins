# Changelog

All notable changes to the `plan-kit` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 (2026-07-18)


### Features

* **plan-kit:** shared plan-shape validation provider ([#95](https://github.com/DarcStar-Technologies/claude-plugins/issues/95)) ([801a222](https://github.com/DarcStar-Technologies/claude-plugins/commit/801a222f0219b54a32b88512de2b251498d17956))

## [Unreleased]

### Added

- Initial `plan-kit` provider plugin: `scripts/validate-plan.sh`, the shared
  deterministic plan-shape gate for the plan-confirm-apply archetype. Validates a
  planner's JSON plan (`summary` string, `actions[]` items with a string `path` and an
  `action` in a caller-supplied `--actions` vocabulary — default `create,modify,delete` —
  and a `questions[]` array), names the first violation, tolerates domain-specific extra
  fields, and reads from a file arg or stdin. No command of its own; resolved at run time
  by consumers, mirroring `edit-kit`.
