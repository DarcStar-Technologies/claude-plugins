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
- **`plugins/_template/`** — the reference plugin and the template the scaffolder
  copies components from. The `_` prefix marks it internal: validators skip
  `_`-prefixed plugins for marketplace membership, so it is never published.
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
- **Minimum capable model.** Subagents/commands set `model:` frontmatter to the
  smallest model that is correct (`haiku` → `sonnet` → `opus`). Anything fully
  deterministic goes in a `scripts/` shell script (with a bats test), not a model.
- **`_template` is a copy source.** The scaffolder copies its component dirs and
  rewrites the literal string `_template` to the new name — avoid that literal for
  anything you want preserved.
- **Commit format is enforced.** commitlint requires Conventional Commits
  (`feat`/`fix`/…, plugin-name or area scope). See `CONTRIBUTING.md`.

## Before you finish a change

Run `scripts/check-all.sh` and `npm test`. For anything touched by the hooks,
`pre-commit run --all-files` mirrors CI most closely.
