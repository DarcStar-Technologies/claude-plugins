# Changelog

All notable changes to this repository's **tooling and structure** are documented
here. Individual plugins maintain their own changelogs under
`plugins/<name>/CHANGELOG.md`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this repository follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Marketplace foundation: `.claude-plugin/marketplace.json` and the `default`
  reference template.
- Mechanized validation scripts under `scripts/` (manifest, docs, and version
  checks) with a `bats` test suite.
- Automation: Conventional Commits enforced by commitlint, release-please for
  per-plugin versioning and changelogs, pre-commit hooks (shellcheck, shfmt,
  markdownlint, actionlint, and the local validators), and GitHub Actions CI.
- Project documentation: `README.md`, `CONTRIBUTING.md`, and `CLAUDE.md`.
- Scaffold provenance tracking: the scaffolder records the source template and
  version in each plugin's `.claude-plugin/scaffold.json`, enforced by
  `validate-manifests.sh` and surfaced (with drift detection) by
  `scripts/scaffold-report.sh`.
- Template drift policy: `scaffold-report.sh --strict` (a CI gate) fails on
  unlisted **major** template drift; `.scaffold-exceptions.json` records
  intentional exceptions as `plugin-name → reason`. Minor/patch drift stays
  informational.
- release-please versions every plugin, including the internal templates under
  `templates/` (kept out of the public catalog by their location, but release-tagged
  so their versions advance through the automated flow and drive drift detection).
  Plugin changelogs hold only an `[Unreleased]` section; release-please writes the
  versioned entries. The release workflow skips cleanly when no plugins are
  registered.
- Multiple named templates: templates live under `templates/` (a sibling of
  `plugins/`, identified by location rather than a name prefix) — `default` plus the
  new `command-suite` archetype — discoverable with `scripts/list-templates.sh` and
  selectable via `forge-scaffold.sh --template <name>`. Components substitute
  `{{NAME}}`/`{{DESC}}` placeholders on copy. Each template is release-managed and
  tagged, and `scaffold-report.sh` computes drift per template. Release-config
  hardening adds `exclude-paths` so a template no longer version-bumps on incidental
  prose-doc touches. Implements #6.
- CI-gated automatic releases: `release.yml` turns on GitHub auto-merge for
  release-please's release PR, so a merged `feat`/`fix` publishes hands-free once
  the required checks (`validate & lint`, `shell tests (bats)`) pass — merging the
  release PR is what tags and publishes. The PR is located from release-please's own
  `pr` output (authoritative and immediate; GitHub's label search index lags a few
  seconds, so a same-run PR would otherwise be missed), with a single label-query
  fallback for a pre-existing PR. The step is best-effort and never fails the
  release job. Requires the repo's `allow_auto_merge`/`allow_squash_merge` settings
  and a `main` branch-protection rule (see CONTRIBUTING.md → "Automated releases").

### Changed

- Scaffolding is unified into plugin-forge's `forge-scaffold.sh` (one engine;
  `--register` toggles marketplace registration, and it also scaffolds standalone
  plugins in portable mode). Removed the separate `scripts/new-plugin.sh` and the
  `templates/*.tmpl` directory; docs/manifest are generated from inline scaffolds.
