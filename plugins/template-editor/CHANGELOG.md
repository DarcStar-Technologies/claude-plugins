# Changelog

All notable changes to the `template-editor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/template-editor--v0.4.0...template-editor--v0.5.0) (2026-07-17)


### Features

* **plugin-forge:** propagate template.json deps into scaffolded plugins (part 2 of [#79](https://github.com/DarcStar-Technologies/claude-plugins/issues/79)) ([#84](https://github.com/DarcStar-Technologies/claude-plugins/issues/84)) ([fba12d8](https://github.com/DarcStar-Technologies/claude-plugins/commit/fba12d8e8fef1c5aa4b5bd367c267e69bc82188f))

## [0.4.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/template-editor-v0.3.0...template-editor--v0.4.0) (2026-07-17)


### Features

* **deps:** use versioned plugin dependencies now that --v tags exist ([#77](https://github.com/DarcStar-Technologies/claude-plugins/issues/77)) ([5b07270](https://github.com/DarcStar-Technologies/claude-plugins/commit/5b07270cf3acf10e09d9704470ff231b86356f09)), closes [#74](https://github.com/DarcStar-Technologies/claude-plugins/issues/74)

## [0.3.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/template-editor-v0.2.0...template-editor-v0.3.0) (2026-07-17)


### Features

* **deps:** declare first-class plugin dependencies in plugin.json ([#69](https://github.com/DarcStar-Technologies/claude-plugins/issues/69)) ([aa1966d](https://github.com/DarcStar-Technologies/claude-plugins/commit/aa1966de21a59eb8bf943ee552b1f435fb6a7270))

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/template-editor-v0.1.0...template-editor-v0.2.0) (2026-07-17)


### Features

* **plugin-editor:** consume the shared edit-kit toolkit (complete the DRY arc) ([#60](https://github.com/DarcStar-Technologies/claude-plugins/issues/60)) ([209c2e4](https://github.com/DarcStar-Technologies/claude-plugins/commit/209c2e424a7f7d9d54be5d60cfd7673263872b92))

## 0.1.0 (2026-07-17)


### Features

* **template-editor:** edit a reference template (plan→confirm→apply), reusing edit-kit ([#57](https://github.com/DarcStar-Technologies/claude-plugins/issues/57)) ([ca0d5e8](https://github.com/DarcStar-Technologies/claude-plugins/commit/ca0d5e884efda555445b8df87e3f106de438e36e))

## [Unreleased]

### Changed

- Retargeted provenance to plan-confirm-apply template v0.4.0 — the version that moved plan-shape validation into the shared plan-kit provider.
- `/edit-template` and the `template-edit-planner` agent now treat `template.json` as a
  first-class manifest: they read it during intake/planning and keep it consistent when an
  edit changes the template's identity (kept in sync with `plugin.json` — the validator
  fails on drift) or its dependencies (a new/removed CLI tool, sibling-plugin reuse,
  library, or MCP server updates the manifest's cross-kind `dependencies`).
- Declare a versioned dependency on the `edit-kit` plugin (`>=0.1.0`) in `plugin.json`, so Claude Code auto-installs it (and transitively `semver`) and enforces the range at load. Enabled by the `<name>--v<version>` release tags (issue #74).

### Added

- The plan step now validates the planner's JSON plan via the shared plan-kit provider — scripts/plan-kit-path.sh resolves plan-kit and the command runs validate-plan.sh --field files --actions create,modify,delete before the confirm gate (this planner's change array is files[], not the archetype's actions[]). Adds a plan-kit >=0.2.0 dependency; under --dry-run validation is advisory (an unresolvable plan-kit or a failing plan still shows the preview), and a plan regenerated in step 4 is re-validated.
- Initial `template-editor` plugin: the template analogue of `plugin-editor`. A
  `/edit-template` command and read-only `template-edit-planner` agent that modify a
  reference template under `templates/` via a plan→confirm→apply flow, plus
  `discover-templates.sh` (picker) and `edit-kit-path.sh` (resolves the shared `edit-kit`
  toolkit at run time). Reuses edit-kit's edit-flow scripts rather than vendoring them;
  built on the `plan-confirm-apply` template.
