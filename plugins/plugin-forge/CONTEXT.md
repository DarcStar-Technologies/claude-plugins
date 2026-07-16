# plugin-forge — Context

> Design notes for humans and AI assistants. plugin-forge is the AI-assisted
> front-end to a deterministic scaffolder: it decides *what* to build from a
> description and asks about anything unclear; a shell script does the mechanical
> file creation.

## Purpose

Generate a new Claude Code plugin from a natural-language description — either
**for this marketplace** (registering it here) or as a **standalone plugin in any
project**. Implements
[#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2) (marketplace)
and [#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)
(portable mode).

## Two modes

`/forge` detects its mode at runtime:

- **Marketplace mode** — inside a checkout of this repo (`scripts/new-plugin.sh` +
  `.claude-plugin/marketplace.json` present). Scaffolds into `plugins/<name>/` and
  registers the plugin in the marketplace catalog + release automation, via
  `scripts/new-plugin.sh`.
- **Portable mode** — anywhere else. Scaffolds a standalone plugin in the current
  directory and registers nothing, via the bundled
  `${CLAUDE_PLUGIN_ROOT}/scripts/forge-scaffold.sh`.

## Mental model

Three layers, split along the repo's core principle — mechanize the
deterministic, use the minimum-capable model for the rest:

| Layer | Who | Responsibility |
| ----- | --- | -------------- |
| Understanding | `agents/plugin-planner.md` (sonnet) | Description → structured plan + clarifying questions. Read-only. |
| Orchestration | `commands/forge.md` | Detect mode; run plan → ask → scaffold → realize → validate. |
| Mechanization (marketplace) | `../../scripts/new-plugin.sh` | Render, copy, register in marketplace/release. |
| Mechanization (portable) | `scripts/forge-scaffold.sh` | Resolve a template, scaffold a standalone plugin. No registration. |

## Template resolution (portable mode)

`forge-scaffold.sh` **resolves** the template — rather than bundling a static copy
— in precedence order:

1. `--template-version <ver>` → the `_template-v<ver>` release tag from this repo,
2. `--template-repo <owner/repo[@ref]>` → that repo (or a git URL / local path),
3. a local `./_template/` directory,
4. the latest `_template` from this repo (the default).

The `_template-v*` release tags are the version source, so there is **no bundled
copy to drift**. Marketplace mode always uses the repo's current `_template`.

## Model selection

- `plugin-planner`: **sonnet** — mapping an open-ended description to a concrete
  plan is genuine judgment: above mechanical work, short of deep architecture.
- `/forge` orchestration runs on the session model; the heavy lifting is delegated
  to shell.

## Challenging concepts & gotchas

- **Two engines, one command.** `forge.md` picks `new-plugin.sh` (marketplace) or
  `forge-scaffold.sh` (portable) based on whether it is inside this repo.
- **Portable docs are inline.** `forge-scaffold.sh` generates the new plugin's
  docs/manifest from small inline scaffolds that mirror `../../templates/*.tmpl`.
  Unifying the two template sources is tracked in
  [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)
  (multiple named templates).
- **Portable needs git + network** for the tag/repo/default sources; a local
  `./_template/` works offline. Resolution fails with a clear message otherwise.
- **Provenance.** Every forged plugin gets `.claude-plugin/scaffold.json` with the
  template + version; portable also records the resolved `source` and `mode`.
- **Ask, don't invent.** The planner emits `questions[]` for anything ambiguous;
  `/forge` must resolve them with the user before creating files.

## References

- Issues: [#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)
  (marketplace), [#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)
  (portable mode)
- Scaffolders: `../../scripts/new-plugin.sh`, `scripts/forge-scaffold.sh`
- Repo conventions: `../../CONTRIBUTING.md`
