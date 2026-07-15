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

- Resolve a **specific** older template version (from git history of
  `plugins/_template/`); plugin-forge supports only the current version today.

## Foundation (done)

Marketplace structure, the `_template` reference plugin, mechanized validators
with a `bats` suite, Conventional Commits + release-please automation, CI gates,
and scaffold provenance with a template-drift policy. See
[`CHANGELOG.md`](./CHANGELOG.md).
