# Roadmap

Planned and proposed work for the DarcStar plugin marketplace. The source of
truth is [GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues);
this file is a curated, human-readable index of the larger items.

## Planned plugins

- **AI-assisted plugin scaffolder** (`plugin-forge`, proposed) — generate a
  plugin from a natural-language description, defaulting to the current template
  version (or a version the user specifies) and prompting for any details it
  can't confidently infer. Delegates the deterministic work to
  `scripts/new-plugin.sh`.
  → [#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)

## Foundation (done)

Marketplace structure, the `_template` reference plugin, mechanized validators
with a `bats` suite, Conventional Commits + release-please automation, CI gates,
and scaffold provenance with a template-drift policy. See
[`CHANGELOG.md`](./CHANGELOG.md).
