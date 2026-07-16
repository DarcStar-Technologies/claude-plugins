---
description: Scaffold a new reference template under templates/ — from a description, guided prompts, or an existing plugin.
argument-hint: "[--from-plugin <plugin-dir>] [<template-name>] [— <what the template is for>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
model: sonnet
---

Create a new **reference template** — an internal plugin under `templates/` whose
component dirs the marketplace scaffolder copies into new plugins. Delegate the
deterministic scaffolding to the shell script, prefer the minimum-capable model for
any component, and **never create anything until the user approves the plan.**

`$ARGUMENTS` may carry a template name, a free-text description of what the template
is for, and/or the flag `--from-plugin <plugin-dir>`. Any of the three input paths
below can start from whatever is already given.

## 1. Require a marketplace repo

Each Bash call runs in a **fresh shell**, so recompute paths every time. Find the
repo root: `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"`.

- A template only means something inside a marketplace repo. If
  `"$ROOT/.claude-plugin/marketplace.json"` does **not** exist, stop and tell the
  user this command must run inside the marketplace repo.
- The scaffolder is `"${CLAUDE_PLUGIN_ROOT}/scripts/template-forge-scaffold.sh"`.

## 2. Pick the input path

Split `$ARGUMENTS` at a `—` change-description separator if present (everything
after it is the literal description; never scan it for flags). Then:

- **From an existing plugin** — if `--from-plugin <plugin-dir>` was given, use that
  plugin as the source (confirm `<plugin-dir>/.claude-plugin/plugin.json` exists). If
  the user asked to base it on a plugin but named none, offer a **picker**: read each
  `"$ROOT"/plugins/*/.claude-plugin/plugin.json` for its `name`/`description` and let
  the user choose with `AskUserQuestion`.
- **From a description** — otherwise, if `$ARGUMENTS` contains a real, actionable
  description of the archetype, use it directly.
- **Guided prompts** — otherwise (thin or absent description), run guided intake
  (step 3).

## 3. Guided intake — only when the description is thin and it's not from a plugin

Mirroring the marketplace's other guided flows, never re-ask anything already given:

- **What archetype is this?** Ask one `AskUserQuestion` — grounded in the existing
  templates (run `"$ROOT/scripts/list-templates.sh"` and skim each) — offering
  concrete, distinct archetype shapes (e.g. "command-only suite", "command + planner
  agent + script", "skill-centric", "script/automation-only"), always keeping the
  built-in **"Other"** free-form option.
- **What should its components be?** Offer 3–5 concrete component-set suggestions for
  the chosen archetype (again with "Other").
- Fold the answers into one clear description, then continue.

## 4. Plan (delegate to the planner subagent)

Invoke the `template-planner` agent (Task tool). Give it `ROOT` and:

- description/guided mode — the composed description;
- from-plugin mode — the **source plugin directory** so it can read that plugin's
  actual components and propose how each maps into the template (keep as-is /
  genericize / drop as too plugin-specific).

It returns a JSON plan: `name`, `description`, `keywords`, `template` (archetype
rationale), `components[]` (`type`, `file`, `responsibility`, `model`, `tools`), and
`questions[]`. If it doesn't return one valid JSON object, ask it to try again.

## 5. Resolve unknowns, then confirm — do NOT create yet

- If the plan has `questions`, ask them (`AskUserQuestion` for discrete choices) and
  re-run the planner if the answers change the plan.
- Present the final plan — the template name, its components and per-component model,
  and (from-plugin mode) which source components will be kept/genericized/dropped.
- Get an explicit go-ahead before creating anything.

## 6. Scaffold deterministically

Pass the description **single-quoted** so punctuation/quotes/`$` can't break the
command. From the plan's `components[]`, collect the distinct component **types**
(`commands`/`agents`/`skills`/`scripts`) into a space-separated `--components` list.

- **Default (description/guided):**
  `"${CLAUDE_PLUGIN_ROOT}/scripts/template-forge-scaffold.sh" <name> --description 'One clear sentence.' --components '<types>' --register "$ROOT"`
- **From a plugin:** add `--from-plugin <plugin-dir>` (the `--components` list is
  ignored — the plugin's own component set is copied):
  `"${CLAUDE_PLUGIN_ROOT}/scripts/template-forge-scaffold.sh" <name> --description '...' --from-plugin <plugin-dir> --register "$ROOT"`

The script writes `templates/<name>/` and registers it in `release-please-config.json`
and `.release-please-manifest.json` — **never** `marketplace.json` (that omission is
what keeps a template internal). If it fails because the destination or package entry
already exists, ask for a different name.

## 7. Realize the plan — only inside `templates/<name>/`

Operate **only** inside the new template's own directory. Never touch anything else.

- **Default mode:** author each planned component into its (empty) dir. Use
  `{{NAME}}`/`{{DESC}}` placeholders for anything that should become the scaffolded
  plugin's identity. Set the planned **minimum-capable `model:`** and a least-privilege
  tool list on every command/agent; push deterministic work into `scripts/*.sh`.
- **From-plugin mode:** the script already copied the components and reversed the
  source plugin's name→`{{NAME}}` / description→`{{DESC}}` (best-effort, textual).
  **Reconcile them:** read each copied file, confirm the identity tokens were
  placeholder-ized, and genericize anything still plugin-specific (hard-coded paths,
  the source plugin's domain nouns, references to its sibling components) so the
  archetype is reusable. Drop any component the plan marked as too plugin-specific.
- Update the template's own `CONTEXT.md`, `README.md`, and `plugin.json` keywords to
  describe the archetype (the scaffolded docs are generic).

## 8. Validate

Run `"$ROOT/scripts/check-all.sh"` and `"$ROOT"`'s `npm test`, and fix what they
report. `list-templates.sh` and `forge-scaffold.sh --template <name>` pick the new
template up automatically.

## 9. Report

Summarize what you created (path + components) and the next steps: flesh out the
component bodies, and land a Conventional Commit for the new template
(`feat(<name>): add the <name> template`). Note that release-please will cut the
first `<name>-v0.1.0` once merged.

Throughout: prefer the minimum-capable model, keep deterministic work in shell, never
edit outside `templates/<name>/`, and never silently guess a requirement — ask.
