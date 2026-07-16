# Roadmap

Planned and proposed work for the DarcStar plugin marketplace. The source of
truth is [GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues);
this file is a curated, human-readable index of the larger items.

## Planned plugins

_None open right now — propose one via a
[GitHub issue](https://github.com/DarcStar-Technologies/claude-plugins/issues)._

## Shipped

- **plugin-forge** — generate a plugin from a natural-language description,
  prompting for anything it can't confidently infer. Delegates the deterministic
  work to its `forge-scaffold.sh`.
  → [#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)
- **Portable mode + unified scaffolder** — `/forge` scaffolds a standalone plugin
  in any project or registers into the marketplace (`--register`); one engine,
  resolving the template from a `<template>-v*` version tag, a repo, a local
  `templates/<name>/`, or the latest from this repo.
  → [#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)
- **semver** — deterministic semver operations (`/semver` validate / compare /
  next-version) for any project; its comparator is reused by the repo's drift
  tooling. → [#10](https://github.com/DarcStar-Technologies/claude-plugins/issues/10)
- **Multiple named templates** — templates live under `templates/` (a sibling of
  `plugins/`, identified by location rather than a name prefix): `default` and
  `command-suite`. Discover with `scripts/list-templates.sh` and select with
  `--template <name>`. Each is release-tagged with per-template drift, and
  release-config `exclude-paths` stops incidental prose-doc touches from bumping a
  template. Adding a new archetype is documented in `CONTRIBUTING.md`.
  → [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)

## Foundation (done)

Marketplace structure, the `default` reference template, mechanized validators
with a `bats` suite, Conventional Commits + release-please automation, CI gates,
and scaffold provenance with a template-drift policy. See
[`CHANGELOG.md`](./CHANGELOG.md).
