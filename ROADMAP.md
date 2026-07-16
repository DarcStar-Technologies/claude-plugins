# Roadmap

Planned and proposed work for the DarcStar plugin marketplace. The source of
truth is [GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues);
this file is a curated, human-readable index of the larger items.

## Planned plugins

- **semver** — deterministic semver operations (`/semver` validate / compare /
  next-version) for any project; its comparator is reused by the repo's drift
  tooling. → [#10](https://github.com/DarcStar-Technologies/claude-plugins/issues/10)

## Shipped

- **plugin-forge** — generate a plugin from a natural-language description,
  prompting for anything it can't confidently infer. Delegates the deterministic
  work to its `forge-scaffold.sh`.
  → [#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)
- **Portable mode + unified scaffolder** — `/forge` scaffolds a standalone plugin
  in any project or registers into the marketplace (`--register`); one engine,
  resolving the template from a `<template>-v*` version tag, a repo, a local
  `_template/`, or the latest from this repo.
  → [#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)

### Follow-ups

- **Multiple named templates** — rearchitect scaffolding so plugin families
  (MCP servers, command suites, agent packs) share common structure and can be
  selected with `--template <name>` (already a flag; only one template exists
  today). Includes release-config hardening so a template doesn't version-bump on
  incidental touches. → [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)

## Foundation (done)

Marketplace structure, the `_template` reference plugin, mechanized validators
with a `bats` suite, Conventional Commits + release-please automation, CI gates,
and scaffold provenance with a template-drift policy. See
[`CHANGELOG.md`](./CHANGELOG.md).
