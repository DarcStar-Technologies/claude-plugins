# Changelog

All notable changes to the `template-editor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/template-editor-v0.1.0...template-editor-v0.2.0) (2026-07-17)


### Features

* **plugin-editor:** consume the shared edit-kit toolkit (complete the DRY arc) ([#60](https://github.com/DarcStar-Technologies/claude-plugins/issues/60)) ([209c2e4](https://github.com/DarcStar-Technologies/claude-plugins/commit/209c2e424a7f7d9d54be5d60cfd7673263872b92))

## 0.1.0 (2026-07-17)


### Features

* **template-editor:** edit a reference template (plan→confirm→apply), reusing edit-kit ([#57](https://github.com/DarcStar-Technologies/claude-plugins/issues/57)) ([ca0d5e8](https://github.com/DarcStar-Technologies/claude-plugins/commit/ca0d5e884efda555445b8df87e3f106de438e36e))

## [Unreleased]

### Added

- Initial `template-editor` plugin: the template analogue of `plugin-editor`. A
  `/edit-template` command and read-only `template-edit-planner` agent that modify a
  reference template under `templates/` via a plan→confirm→apply flow, plus
  `discover-templates.sh` (picker) and `edit-kit-path.sh` (resolves the shared `edit-kit`
  toolkit at run time). Reuses edit-kit's edit-flow scripts rather than vendoring them;
  built on the `plan-confirm-apply` template.
