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

## One scaffolder, two modes

`scripts/forge-scaffold.sh` is the single scaffolding engine. The modes differ
only in registration:

- **Marketplace mode** (`--register <repo-root>`) — scaffold into
  `<root>/plugins/<name>` and register the plugin in that repo's marketplace
  catalog + release automation.
- **Portable mode** (default) — scaffold a standalone plugin in the current
  directory (or `--out <dir>`) and register nothing.

`/forge` detects which mode to use (a marketplace repo is present → `--register`;
otherwise portable) and calls the same script either way.

## Mental model

Three layers, split along the repo's core principle — mechanize the
deterministic, use the minimum-capable model for the rest:

| Layer | Who | Responsibility |
| ----- | --- | -------------- |
| Understanding | `agents/plugin-planner.md` (sonnet) | Description → structured plan + clarifying questions. Read-only. |
| Orchestration | `commands/forge.md` | Detect mode; run plan → ask → scaffold → realize → validate. |
| Mechanization | `scripts/forge-scaffold.sh` | Resolve a template, scaffold, optionally register (`--register`). No model. |

## Template resolution

`forge-scaffold.sh` **resolves** the template — rather than bundling a static copy
— in precedence order:

0. `--register <root>` → `<root>/plugins/<template>` (marketplace),
1. `--template-version <ver>` → the `<template>-v<ver>` release tag from this repo,
2. `--template-repo <owner/repo[@ref]>` → that repo (or a git URL / local path),
3. a local `./<template>/` directory,
4. the latest `<template>` from this repo (the default).

The `<template>-v*` release tags are the version source, so there is **no bundled
copy to drift**.

## Model selection

- `plugin-planner`: **sonnet** — mapping an open-ended description to a concrete
  plan is genuine judgment: above mechanical work, short of deep architecture.
- `/forge` orchestration runs on the session model; the heavy lifting is delegated
  to shell.

## Challenging concepts & gotchas

- **Components only from the template.** The scaffolder copies the template's
  `commands/agents/skills/scripts`, but generates docs/manifest from inline
  scaffolds. A custom `--template-repo` therefore contributes *components*, not
  docs — honoring custom-template docs is tracked in
  [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6).
- **Portable needs git + network** for the tag/repo/default sources; a local
  `./<template>/` works offline. Resolution fails with a clear message otherwise.
- **Provenance.** Every forged plugin gets `.claude-plugin/scaffold.json` with the
  template, resolved `source`, and `mode`.
- **Ask, don't invent.** The planner emits `questions[]` for anything ambiguous;
  `/forge` must resolve them with the user before creating files.

## References

- Issues: [#2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2)
  (marketplace), [#5](https://github.com/DarcStar-Technologies/claude-plugins/issues/5)
  (portable mode), [#6](https://github.com/DarcStar-Technologies/claude-plugins/issues/6)
  (multiple templates)
- Scaffolder: `scripts/forge-scaffold.sh`
- Repo conventions: `../../CONTRIBUTING.md`
