---
description: Safely modify an existing reference template under templates/ — add a component, change a behavior, fix a bug, or remove a capability — via a plan-confirm-apply flow with template-appropriate housekeeping reused from edit-kit.
argument-hint: "[--dry-run] [--template=<dir>] [--type=add|change|fix|remove] [<template-dir>] [— <what to change>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
model: sonnet
---

Modify an existing **reference template** (under `templates/`) safely. This is the
plan → confirm → apply archetype specialized for templates: work through the steps in
order and **never edit anything until the user approves the plan.** It is the template
analogue of `/edit-plugin`.

`$ARGUMENTS` is the target template directory followed by the change to make — both
optional (guided intake fills what's missing). The flags `--dry-run`,
`--template=<dir>`, and `--type=add|change|fix|remove` may appear before the change
description.

## 1. Require a marketplace repo, then locate the template

Each Bash call runs in a **fresh shell**, so recompute paths every time. Templates only
exist inside the marketplace repo — find the root **git-independently** by walking up
from the current directory to the nearest ancestor containing
`.claude-plugin/marketplace.json` (do **not** use `git rev-parse` — the checkout may be
vendored inside a larger repo or not a git worktree). If there is no such ancestor, stop
and say this command runs inside the marketplace repo.

- **Split off the change description, then parse flags.** Everything after the `—`
  change-description separator is the **literal change text** — never scanned for flags.
  What precedes it is the **directive segment**: the flags `--dry-run` (preview and stop,
  step 5), `--template=<dir>` (authoritative target dir), `--type=<...>` (authoritative
  change type, carried to step 2 and the planner), in any order, plus an optional
  positional `<template-dir>`. **If there is no `—` separator,** recognize flags only as
  **leading** tokens (before `<template-dir>`) and treat everything after `<template-dir>`
  as the change text — so a flag-looking token in the change text stays literal.
- **Resolve the target template:** `--template=<dir>` is authoritative and wins; if a
  positional `<template-dir>` was **also** given, drop that redundant token so it can't
  leak into the change text. Otherwise use a positional `<template-dir>`; else the current
  directory if it is itself a template; else offer a **picker** — run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/discover-templates.sh"`; if it prints a non-empty JSON
  array, choose with `AskUserQuestion` (≤4 options — label = `name`, description =
  `description`; use the entry's absolute `path`; the built-in "Other" is added for you).
  If it **exits 2 or returns `[]`** (not a marketplace / no templates), fall back to free
  text; if it fails otherwise (a non-zero exit with an error on stderr), **relay that
  error** rather than silently falling back.
- **The target MUST be under `templates/`** (a dir with its own `.claude-plugin/plugin.json`).
  If the resolved path isn't a template under `templates/`, stop — this command never
  edits `plugins/` (that's `/edit-plugin`'s job).

## 2. Guided intake — fill in what's missing

If the change description is already fully specified, skip to step 3 (still carrying an
authoritative `--type=`). Otherwise gather what's missing via `AskUserQuestion` (never
re-asking what a flag/text already answered):

- **Change type** (skip if `--type=` given): Add a component / Change a behavior / Fix a
  bug / Remove a capability.
- **Specific suggestions:** read the target template's own `plugin.json`, `template.json`,
  `CONTEXT.md`, `README.md`, and its components, then offer 3–4 concrete suggestions
  grounded in this template (keeping the built-in "Other"). Fold everything into one
  change description.

When the plan touches `template.json`, apply those edits like any other file (step 6).
`verify-repo.sh` (step 8) runs `validate-manifests.sh` **advisory** (repo-wide checks are
relayed as `WARNING:` lines, not hard blocks), so **treat any template.json drift or
malformed-descriptor warning it surfaces as a must-fix before finishing** — otherwise
pre-commit/CI hard-fail on it later.

## 3. Plan (delegate to the planner)

Invoke the `template-edit-planner` agent (Task tool) with the template dir and the
change — plus the authoritative change type when `--type=` was given. It returns a JSON
plan (`summary`, `changeType`, `files[]`, `changelog`, `bumpLevel`, `risks[]`,
`questions[]`). If it doesn't return one valid JSON object, ask it to try again.

**Validate the plan's shape before acting on it.** The check lives in the shared
**`plan-kit`** provider. First **extract the plan as raw JSON**: take the JSON object the
planner returned and **strip any surrounding fenced code block** (the planner wraps it in
one) — pass exactly that object, never the fence, to the validator. Resolve plan-kit once
(recompute in each fresh shell): `PK="$("${CLAUDE_PLUGIN_ROOT}/scripts/plan-kit-path.sh")"`,
then run `"$PK/validate-plan.sh" --field files --actions create,modify,delete` on the
extracted JSON (this planner names its change array `files[]`, whose actions are
`create`/`modify`/`delete`).

- On a **shape/vocabulary** violation (e.g. `files[0].action must be one of: …`), tell the
  planner exactly what `validate-plan.sh` reported on stderr and ask for a corrected plan,
  re-checking at most **3** times.
- On a **`malformed JSON`** error, first re-check your **own** extraction — that error
  almost always means the fenced code block wasn't stripped, which the planner cannot fix;
  strip it and re-run before re-prompting the planner.
- **Under `--dry-run`, validation is advisory:** if plan-kit can't be resolved, or the
  plan still fails after the retries, note what was skipped/failed and **continue to the
  preview** — a dry run changes nothing on disk.
- **Otherwise it is a hard gate:** an unresolvable plan-kit (tell the user to install the
  `plan-kit` plugin or set `PLAN_KIT_DIR`) or a plan that still fails after the retries
  (tell the user planning failed, quoting the last error) **stops** the command — never
  apply an unvalidated plan.

Validate here, strictly before step 4/5 — and **re-validate the same way any plan the
planner regenerates in step 4.**

## 4. Resolve unknowns — ask, don't guess

If the plan has `questions`, ask them (`AskUserQuestion` for discrete choices) and
re-run the planner if the answers change the plan. **A regenerated plan is not yet
gated** — put it back through step 3's plan-kit validation before continuing to the
confirm step.

## 5. Confirm the plan — do NOT edit yet

Present the plan: files it will touch, the `[Unreleased]` entry, the version impact, and
any `risks`.

- **If `--dry-run`:** label it a **DRY RUN / PREVIEW**, state that **nothing on disk was
  or will be changed**, give the exact command to re-run without `--dry-run`, then
  **STOP** — do not run steps 6–9.
- **Otherwise:** get an explicit go-ahead, then continue.

## 6. Apply the edits

Make exactly the planned edits, operating **only inside the target `templates/<name>/`
directory**. **Preserve the template's `{{NAME}}`/`{{DESC}}` placeholders** — a
component keeps them as the scaffolded plugin's identity; never hard-code a concrete
name/description in a component. Put anything deterministic into a `scripts/*.sh` step.

## 7. Verify the edits landed

Re-read every file in the plan's `files[]` and confirm the change is actually present (a
semantic check, not just that it parses). For a deletion, confirm it's gone. Fix
anything that didn't land; if you can't, stop and say what's missing.

## 8. Housekeeping — the edit-kit toolkit

edit-kit provides the deterministic edit-flow scripts. Resolve its dir **once** and reuse
it (recompute in each fresh shell):
`EK="$("${CLAUDE_PLUGIN_ROOT}/scripts/edit-kit-path.sh" "<template-dir>")"`. If that
fails, tell the user to install the `edit-kit` plugin (or set `EDIT_KIT_DIR`). Then run,
relaying each script's output:

1. `"$EK/check-structure.sh" <template-dir>` — structural validation. Fix what it reports
   (or surface it) before continuing.
2. `"$EK/update-changelog.sh" <template-dir> <category> "<bullet>"` — record the change
   under `[Unreleased]`, using the plan's `changelog.category` and `bullet`.
3. `"$EK/sync-version.sh" <template-dir> <bumpLevel>` — version guidance; relay verbatim
   (templates are release-please-managed, so it prints the Conventional Commit to land —
   do NOT hand-bump).
4. **Only if the plan created any new top-level `scripts/*.sh`:**
   `"$EK/scaffold-test.sh" <template-dir> <path...>` — write a bundled `scripts/tests/<name>.bats`
   stub for each (idempotent). Runs before verify-repo.sh so its bundled-tests check
   covers them.
5. `"$EK/verify-repo.sh" <template-dir> <files...>` — post-apply cross-checks (advisory:
   repo-wide `check-all.sh` and centralized tests WARN; only the template's own bundled
   `scripts/tests/*.bats` hard-fail). On a non-zero exit, fix and re-check; relay any
   `WARNING:` lines.

There is **no install/reload step** — a template is never installed.

## 9. Summary

Summarize: each file touched and what changed; any bundled test stub scaffolded; the
`[Unreleased]` changelog entry; and the version/commit guidance from `sync-version.sh`.

Throughout: ask when unsure, keep deterministic work in scripts, prefer the
minimum-capable model for any new component, preserve `{{NAME}}`/`{{DESC}}`, and never
edit outside the target template's directory.
