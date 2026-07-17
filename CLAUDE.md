# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A public **Claude Code plugin marketplace** for DarcStar Technologies. Each plugin
is an independently SemVer-versioned, self-documenting unit under `plugins/`. The
repository is automated end to end — Conventional Commits drive versioning and
changelogs; pre-commit hooks and CI enforce structure.

## Common commands

```bash
npm install                 # install commitlint + markdownlint (dev tooling)
plugins/plugin-forge/scripts/forge-scaffold.sh NAME --register .   # scaffold + register a plugin
scripts/list-templates.sh   # list scaffolding templates (the plugins under templates/)
scripts/scaffold-report.sh  # template provenance + drift per plugin
scripts/check-all.sh        # manifests + docs + versions (the core gate)
npm test                    # bats tests:  bats scripts/tests
bats scripts/tests/validate-manifests.bats   # run a single test file
scripts/lint.sh             # shellcheck / shfmt / markdownlint / actionlint
pre-commit run --all-files  # everything the commit hooks enforce
```

There is no build step; plugins are Markdown, JSON, and shell.

## Architecture

- **`.claude-plugin/marketplace.json`** — the catalog. Every *public* plugin has
  an entry (`name`, `source`, `description`) — no `version`, since `plugin.json`
  is the source of truth and release-please only updates that. Kept in sync by the
  scaffolder.
- **`plugins/<name>/`** — one plugin each. Required: `.claude-plugin/plugin.json`
  (name must equal the directory, version must be semver), `CONTEXT.md`,
  `CHANGELOG.md`, `README.md`, and — for public plugins — `.claude-plugin/scaffold.json`
  (template provenance). Optional component dirs: `commands/`, `agents/`,
  `skills/`, `scripts/`, `hooks/`.
- **Templates (`templates/*/`)** — the reference plugins (a sibling tree to
  `plugins/`) the scaffolder copies components from. `default` is the
  general-purpose base; `command-suite` is an archetype for command-only plugins.
  Living under `templates/` — not any name prefix — marks them internal: validators
  skip them for marketplace membership, so they are never published, but they
  **are** release-managed and tagged (`<name>--v*`), for drift comparison and
  `--template-version` fetches. List them with `scripts/list-templates.sh`; select
  one with `forge-scaffold.sh --template <name>` (default `default`). See
  `CONTRIBUTING.md` → "Adding a template" to add more.
- **`plugins/plugin-forge/scripts/forge-scaffold.sh`** — the single scaffolder.
  In the repo it runs with `--register .` (marketplace mode: writes to `plugins/`
  and registers); portably it creates a standalone plugin elsewhere. Docs and the
  manifest come from inline scaffolds in that script (there is no `templates/` dir).
- **`scripts/`** — mechanized bash. `lib/common.sh` is shared (derives repo root
  from its own path, not git, so it works in test fixtures). Validators:
  `validate-manifests.sh`, `check-plugin-docs.sh`, `check-versions.sh`;
  `check-all.sh` runs all three. Tests in `scripts/tests/*.bats`.

## Non-obvious conventions

- **Do not hand-edit versions or released changelog sections.** release-please
  (`.github/workflows/release.yml`, `release-please-config.json`,
  `.release-please-manifest.json`) bumps `plugin.json` versions and generates each
  plugin's `CHANGELOG.md` from Conventional Commits on merge to `main`. The
  repo-root `CHANGELOG.md` is curated by hand and covers tooling/structure only.
- **Release tags are `<name>--v<version>` (double hyphen).** `release-please-config.json`
  sets `tag-separator: "--"`, so a release of component `<name>` is tagged
  `<name>--v<version>` (e.g. `edit-kit--v0.2.0`). This is exactly the tag scheme Claude
  Code's plugin-dependency resolver matches when a `plugin.json` `dependencies` entry
  carries a version range — the `--v` is a prefix match, so hyphenated plugin names
  resolve unambiguously. Legacy single-hyphen `<name>-v*` tags (releases from before this
  change) remain valid history; both `scaffold-upgrade`'s `check-upgrade.sh` and
  plugin-forge's `forge-scaffold.sh --template-version` resolve either format.
- **Registering a plugin is three files.** A new plugin must be added to
  `marketplace.json`, `release-please-config.json`, and
  `.release-please-manifest.json`. `forge-scaffold.sh --register` does all three
  with `jq` — use it rather than editing by hand.
- **Scaffold provenance is tracked.** Every public plugin has
  `.claude-plugin/scaffold.json` recording the template and template version it
  was generated from (written by the scaffolder, required by
  `validate-manifests.sh`). `scripts/scaffold-report.sh` prints a provenance
  table. CI runs it with `--strict`, which **fails on `MAJOR-DRIFT`** (the
  template is a major version ahead of what a plugin recorded) unless that plugin
  is listed with a reason in `.scaffold-exceptions.json`. Minor/patch drift is
  informational and never fails.
- **Templates carry a `template.json` manifest.** Each `templates/<name>/` has a
  `template.json` (the template's authoritative metadata: name, description, author,
  license, keywords) whose **`dependencies`** array uses dep-doctor's descriptor
  vocabulary (`{kind, name, version?, reason?}`, `kind` ∈ `plugin`/`cli`/`library`/`mcp`)
  — the one place a template's *cross-kind* deps live, since `plugin.json` `dependencies`
  is plugin-only. `validate-manifests.sh` requires it, checks the descriptors, and
  enforces that its shared identity fields match `plugin.json` (no drift). `version` stays
  out of it (release-please owns that in `plugin.json`). The scaffolder propagates these
  deps into scaffolded plugins (plugin-kind → their `plugin.json`; other kinds → their
  CONTEXT.md).
- **Minimum capable model.** Subagents/commands set `model:` frontmatter to the
  smallest model that is correct (`haiku` → `sonnet` → `opus`). Anything fully
  deterministic goes in a `scripts/` shell script (with a bats test), not a model.
- **Templates are copy sources.** The scaffolder copies a template's component
  dirs and substitutes `{{NAME}}`/`{{DESC}}` placeholders in them — use those for
  anything that should become the new plugin's identity. A template's prose docs
  (`README.md`/`CONTEXT.md`/`CHANGELOG.md`) are in the release config's
  `exclude-paths`, so incidental doc-only edits don't cut a new template version —
  only changes to its components or manifest do.
- **Commit format is enforced.** commitlint requires Conventional Commits
  (`feat`/`fix`/…, plugin-name or area scope). See `CONTRIBUTING.md`.

## Before you finish a change

Run `scripts/check-all.sh` and `npm test`. For anything touched by the hooks,
`pre-commit run --all-files` mirrors CI most closely.
