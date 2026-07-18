# Changelog

All notable changes to the `plan-confirm-apply` template are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plan-confirm-apply--v0.3.0...plan-confirm-apply--v0.4.0) (2026-07-18)


### Features

* **plan-confirm-apply:** validate plans via the shared plan-kit provider ([#97](https://github.com/DarcStar-Technologies/claude-plugins/issues/97)) ([cb1f1f5](https://github.com/DarcStar-Technologies/claude-plugins/commit/cb1f1f5731e219ab824ecabf601bf59923ba7444))

## [0.3.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plan-confirm-apply--v0.2.0...plan-confirm-apply--v0.3.0) (2026-07-18)


### Features

* **plan-confirm-apply:** add validate-plan.sh plan-shape gate to the template ([#92](https://github.com/DarcStar-Technologies/claude-plugins/issues/92)) ([07103bf](https://github.com/DarcStar-Technologies/claude-plugins/commit/07103bf1c41aa99b78cafc71601ce1eff9615fa5))

## [0.2.0](https://github.com/DarcStar-Technologies/claude-plugins/compare/plan-confirm-apply-v0.1.0...plan-confirm-apply--v0.2.0) (2026-07-17)


### Features

* **templates:** add a `template.json` manifest with cross-kind dependencies (part 1 of [#79](https://github.com/DarcStar-Technologies/claude-plugins/issues/79)) ([#80](https://github.com/DarcStar-Technologies/claude-plugins/issues/80)) ([8f762bb](https://github.com/DarcStar-Technologies/claude-plugins/commit/8f762bb0237759d66f120b087dd3b373999ef4a6))

## 0.1.0 (2026-07-16)


### Features

* **plan-confirm-apply:** add the plan-confirm-apply template ([#48](https://github.com/DarcStar-Technologies/claude-plugins/issues/48)) ([17524f1](https://github.com/DarcStar-Technologies/claude-plugins/commit/17524f15239a8b38433be5227ee59d16707269ff))

## [Unreleased]

### Removed

- scripts/validate-plan.sh — the plan-shape gate moved to the plan-kit provider plugin, so one implementation is shared and fixes propagate to every plan-confirm-apply plugin instead of each carrying a copy.

### Changed

- guided-change.md's plan-kit gate is hardened: it now re-validates a plan the planner regenerates in step 4 (not just the initial one), treats validation as advisory under --dry-run (an unresolvable plan-kit or a failing plan still shows the preview), strips the planner's fenced code block before validating, and distinguishes a malformed-JSON error (re-extract locally) from a shape violation (re-prompt the planner).
- guided-change.md now validates the planner's plan via the shared plan-kit provider — it resolves plan-kit with scripts/plan-kit-path.sh and runs its validate-plan.sh (default vocabulary create,modify,delete; pass --actions for a different set) — instead of a template-local script.

### Added

- scripts/plan-kit-path.sh — a run-time locator for the plan-kit provider ($PLAN_KIT_DIR -> marketplace ancestor -> PATH), plus a plan-kit plugin dependency in template.json that forge-scaffold.sh propagates into every scaffolded plugin's plugin.json.
- Initial `plan-confirm-apply` template: the plan→confirm→apply archetype — a guided
  `guided-change` command, a read-only `{{NAME}}-planner` subagent, and a
  `discover-targets.sh` discovery script. Distilled from the `plugin-editor` plugin.
