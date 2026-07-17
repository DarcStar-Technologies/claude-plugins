# template-editor

Modify an existing **reference template** (under `templates/`) safely — add a
component, change a behavior, fix a bug, or remove a capability — with clarifying
questions, a plan → confirm → apply gate, and template-appropriate housekeeping.

It is the **template analogue of [`plugin-editor`](../plugin-editor/)** (as
[`template-forge`](../template-forge/) is to [`plugin-forge`](../plugin-forge/)), built
on the [`plan-confirm-apply`](../../templates/plan-confirm-apply/) archetype. The
deterministic edit-flow steps are **reused from the [`edit-kit`](../edit-kit/)
toolkit** — resolved at run time, never vendored.

## Usage

```text
/edit-template [--dry-run] [--template=<dir>] [--type=add|change|fix|remove] [<template-dir>] [— <what to change>]
```

Runs inside the marketplace repo. Omit the template and it lists the reference
templates for you to pick from; omit the change and it runs a guided intake (change
type → suggestions grounded in that template). The flow is **plan → confirm → apply**:
nothing is edited until you approve the plan, and it operates **only inside the target
`templates/<name>/`**, preserving the template's `{{NAME}}`/`{{DESC}}` placeholders.

Examples:

```text
/edit-template                                  # pick a template, then describe the change
/edit-template templates/plan-confirm-apply — add a --json flag to discover-targets.sh
/edit-template --type=fix templates/command-suite
```

After applying, it runs edit-kit's `check-structure.sh`, `update-changelog.sh`,
`sync-version.sh`, `scaffold-test.sh` (for new scripts), and `verify-repo.sh`, then
summarizes. Templates are release-please-managed, so it prints the Conventional Commit
to land rather than hand-bumping.

## How it works

The reasoning (interpreting the request, editing components, preserving placeholders)
runs on a model; everything deterministic is a tested shell script. Template discovery
(`discover-templates.sh`) and edit-kit resolution (`edit-kit-path.sh`) are this plugin's
own; the edit-flow scripts come from `edit-kit`. See [`CONTEXT.md`](./CONTEXT.md).

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
