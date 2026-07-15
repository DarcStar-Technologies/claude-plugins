# Changelog

All notable changes to this repository's **tooling and structure** are documented
here. Individual plugins maintain their own changelogs under
`plugins/<name>/CHANGELOG.md`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this repository follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Marketplace foundation: `.claude-plugin/marketplace.json`, plugin templates in
  `templates/`, and the `_template` reference plugin.
- Mechanized validation scripts under `scripts/` (manifest, docs, and version
  checks) with a `bats` test suite.
- Automation: Conventional Commits enforced by commitlint, release-please for
  per-plugin versioning and changelogs, pre-commit hooks (shellcheck, shfmt,
  markdownlint, actionlint, and the local validators), and GitHub Actions CI.
- Project documentation: `README.md`, `CONTRIBUTING.md`, and `CLAUDE.md`.
- Scaffold provenance tracking: `new-plugin.sh --template` records the source
  template and version in each plugin's `.claude-plugin/scaffold.json`, enforced
  by `validate-manifests.sh` and surfaced (with drift detection) by
  `scripts/scaffold-report.sh`.
- Template drift policy: `scaffold-report.sh --strict` (a CI gate) fails on
  unlisted **major** template drift; `.scaffold-exceptions.json` records
  intentional exceptions as `plugin-name → reason`. Minor/patch drift stays
  informational.
- release-please versions every plugin, including the internal `_template`
  reference (kept out of the public catalog by its `_` prefix, but release-tagged
  so its version advances through the automated flow and drives drift detection).
  Plugin changelogs hold only an `[Unreleased]` section; release-please writes the
  versioned entries. The release workflow skips cleanly when no plugins are
  registered.
