# edit-kit — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Provide the **one canonical implementation** of the deterministic edit-flow steps that
both `plugin-editor` (edits plugins) and `template-editor` (edits templates) need —
changelog insertion, context-aware version guidance, structural validation, post-edit
repo verification, and bundled-test scaffolding — so neither vendors its own copy.

## Mental model

edit-kit is a **provider plugin**: no command, no agent, no skill — just `scripts/`. It
is the edit-flow analogue of the `semver` plugin (which provides `semver.sh`) and
`scaffold-upgrade` (which provides `check-upgrade.sh`): a plugin that *owns* a
deterministic tool other plugins **resolve at run time** rather than copy. Every script
takes a **target directory** (a plugin or a template) as its first argument and confines
itself to that directory's concerns.

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `scripts/check-structure.sh` | Shell | Structural validation of a target dir (manifest + semver, docs, changelog shape, shellcheck) — the domain-agnostic half of what was plugin-editor's `check-template.sh`. |
| `scripts/update-changelog.sh` | Shell | Insert a bullet under `[Unreleased] > ### <category>`. |
| `scripts/sync-version.sh` | Shell | release-please guidance vs. standalone hand-bump (resolves the `semver` engine). |
| `scripts/scaffold-test.sh` | Shell | Scaffold a bundled, skipped bats stub for each newly created target script. |
| `scripts/verify-repo.sh` | Shell | Post-apply cross-checks (`check-all.sh` + target `bats`), scoped & advisory. |
| `scripts/lib/plan-paths.sh` | Shell (sourced) | Shared `norm_rel` plan-path normalizer. |

## Challenging concepts & gotchas

- **No command by design.** edit-kit is a library, not a user-facing plugin — it
  deliberately ships no `commands/`/`agents/`/`skills/`. Its consumers own the
  model-driven flow; edit-kit owns only the mechanical steps.
- **Resolved at run time, never vendored.** Consumers find a script via
  `$EDIT_KIT_DIR` → a marketplace ancestor's `plugins/edit-kit/scripts/` → `PATH`
  (the same pattern `sync-version.sh` uses for `$SEMVER_BIN` and `check-template.sh`
  for `$CHECK_UPGRADE_BIN`). A copy in a consumer would be drift waiting to happen.
- **Target-agnostic.** Every script operates on any plugin-shaped directory — a
  published plugin under `plugins/` or a reference template under `templates/`. What
  is plugin- or template-*specific* (template-drift, install-status, plugin/template
  discovery) stays in the consumer, not here.
- **`sync-version.sh` still resolves `semver`** and **`check-structure.sh`/`verify-repo.sh`
  shellcheck the target's scripts** — those run-time dependencies (`jq`, `shellcheck`,
  the `semver` engine) are unchanged by the move to edit-kit.
- **Tests live at the repo root.** Per repo convention, edit-kit's script tests are at
  `scripts/tests/edit-kit-*.bats`, not bundled in the plugin.
