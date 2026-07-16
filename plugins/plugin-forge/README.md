# plugin-forge

Generate a new Claude Code plugin from a natural-language description. plugin-forge
infers the name, components, tools, and minimum-capable models, asks you about
anything it can't confidently infer, and hands the mechanical work to a shell
scaffolder — either **for this marketplace** or as a **standalone plugin in any
project**.

## Installation

```text
/plugin marketplace add DarcStar-Technologies/claude-plugins
/plugin install plugin-forge@darcstar
```

## Usage

`/forge` auto-detects its mode.

**In the marketplace repo** — scaffolds and registers a plugin here:

```text
/forge a plugin with a /changelog command that summarizes git commits since the last tag
```

**Anywhere else (portable mode)** — scaffolds a standalone plugin in the current
project, registering nothing:

```text
/forge a plugin that lints Dockerfiles --portable
```

Portable mode resolves the template, in order, from `--template-version <ver>`
(the `_template-v<ver>` release tag), `--template-repo <owner/repo[@ref]>`, a local
`./_template/`, or the latest from this repo. plugin-forge plans from your
description (asking about anything unclear), scaffolds via the right engine, fills
in the components, and validates.

## Notes

- Marketplace mode requires a checkout of this repo (it calls the repo's scripts);
  portable mode works in any project.
- Portable mode needs `git` + network for the tag/repo/default template sources; a
  local `./_template/` works offline.

## Development

See [`CONTEXT.md`](./CONTEXT.md) for the design and
[`CHANGELOG.md`](./CHANGELOG.md) for release history.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
