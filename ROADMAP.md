# Roadmap

Planned and proposed work for the DarcStar plugin marketplace. The source of
truth is [GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues);
this file is a curated, human-readable index of the larger items.

## Planned plugins

_Nothing open right now — propose ideas via
[GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues)._

## Shipped

- **plugin-forge** — generate a plugin from a natural-language description,
  defaulting to the current template version and prompting for anything it can't
  confidently infer. Delegates the deterministic work to `scripts/new-plugin.sh`.
  → [#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)

### Follow-ups

- **Portable mode for plugin-forge** — scaffold a standalone plugin outside this
  repo: resolve the template from a local `_template/`, a `_template-v*` version
  tag, or a specified repo (no bundled copy that could drift), and make
  marketplace/release registration optional. Relocating `new-plugin.sh` alone
  does not achieve this.
  → [#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)
- **Multiple named templates** — rearchitect scaffolding so plugin families
  (MCP servers, command suites, agent packs) share common structure and can be
  selected with `--template <name>` (already a flag; only one template exists
  today). → [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)
- Resolving a **specific** older template version folds into #5 — fetch the
  `<template>-v*` version tag rather than reading git history.

## Foundation (done)

Marketplace structure, the `_template` reference plugin, mechanized validators
with a `bats` suite, Conventional Commits + release-please automation, CI gates,
and scaffold provenance with a template-drift policy. See
[`CHANGELOG.md`](./CHANGELOG.md).
