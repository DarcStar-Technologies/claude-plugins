# Changelog

All notable changes to the `template-editor` plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial `template-editor` plugin: the template analogue of `plugin-editor`. A
  `/edit-template` command and read-only `template-edit-planner` agent that modify a
  reference template under `templates/` via a plan→confirm→apply flow, plus
  `discover-templates.sh` (picker) and `edit-kit-path.sh` (resolves the shared `edit-kit`
  toolkit at run time). Reuses edit-kit's edit-flow scripts rather than vendoring them;
  built on the `plan-confirm-apply` template.
