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
- Resolve a **specific** older template version (from git history of
  `plugins/_template/`); plugin-forge supports only the current version today.

## Foundation (done)

Marketplace structure, the `_template` reference plugin, mechanized validators
with a `bats` suite, Conventional Commits + release-please automation, CI gates,
and scaffold provenance with a template-drift policy. See
[`CHANGELOG.md`](./CHANGELOG.md).
