# template-forge

Scaffold a new **reference template** — the internal plugins under `templates/` that
the marketplace scaffolder copies component directories from — from a natural-language
description, guided prompts, or an existing plugin's components.

It's the template analogue of [`plugin-forge`](../plugin-forge/) (which creates
plugins): the reasoning parts run on a model, and the deterministic scaffolding +
release-registration is a tested shell script.

## Usage

```text
/forge-template [--from-plugin <plugin-dir>] [<template-name>] [— <what the template is for>]
```

Three input paths:

- **From a description** — describe the archetype and it plans and scaffolds a fresh
  template.
- **Guided prompts** — omit the description and it asks what archetype you want and
  which components it should contribute (always with a free-form option).
- **From an existing plugin** — `--from-plugin <dir>` reverse-engineers that plugin's
  components into a template, replacing the plugin's own name/description with the
  `{{NAME}}`/`{{DESC}}` placeholders the scaffolder later re-substitutes. Omit the
  directory and it offers a picker.

The flow is **plan → confirm → create**: nothing is written until you approve the
plan. A new template is registered for release management
(`release-please-config.json` + `.release-please-manifest.json`) but is **never**
added to `marketplace.json` — that omission is exactly what keeps it internal.

Examples:

```text
/forge-template — a command-only suite backed by one shared script
/forge-template report-suite — an archetype for reporting commands
/forge-template --from-plugin plugins/semver  # base a template on the semver plugin
```

After it finishes, land a Conventional Commit (`feat(<name>): add the <name>
template`) and release-please cuts the first `<name>-v0.1.0`.

## How it works

Interpreting the request and authoring/genericizing components runs on a model;
everything deterministic — creating `templates/<name>/`, the reverse
name→placeholder substitution, and the release registration — is the tested
`scripts/template-forge-scaffold.sh`. See [`CONTEXT.md`](./CONTEXT.md).

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
