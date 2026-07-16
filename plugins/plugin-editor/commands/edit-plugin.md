---
description: Modify an existing plugin — add a feature, change behavior, fix a bug, or remove a capability — with clarifying questions, template checks, changelog + version updates, and a reload hint.
argument-hint: "[--dry-run] [--plugin=<dir>] [--type=add|change|fix|remove] [<plugin-dir>] [— <what to change>]"
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Task, AskUserQuestion
model: sonnet
---

Modify an existing Claude Code plugin safely. Work through these steps in order and
**never edit anything until the user approves the plan.**

`$ARGUMENTS` is the target plugin directory followed by the change to make — both
optional, since guided intake (step 2) can supply whatever is missing. Any of the
leading flags `--dry-run`, `--plugin=<dir>`, and `--type=add|change|fix|remove` may
precede them (see below).

## 1. Locate the plugin

- **First, parse any leading flags.** Recognize `--dry-run`, `--plugin=<dir>`, and
  `--type=add|change|fix|remove` as flags **only when they are leading tokens** of
  `$ARGUMENTS` (before `<plugin-dir>` and the change text), in any order. Strip each
  one you find and remember it. The **leading-token rule is strict**: a `--dry-run`,
  `--plugin=`, or `--type=` that appears **inside the change description** (e.g. "add
  a `--dry-run` flag to …" or "fix the `--type=` parser") is literal content — leave
  it in place and do **not** treat it as a flag.
  - `--dry-run` → this is a **dry run**: you will preview the plan and stop, never
    touching disk (see step 5).
  - `--plugin=<dir>` → use `<dir>` as the resolved plugin directory and skip the
    positional-arg / cwd / picker resolution below.
  - `--type=<...>` → the change type is known; step 2 will not re-ask it.
- **Resolve the plugin directory** (skip if `--plugin=` already supplied one): if the
  remaining `$ARGUMENTS` names a directory, use it. Otherwise, if the current
  directory contains `.claude-plugin/plugin.json`, use that.
- If neither gives a target, **offer a picker** instead of guessing: run
  `"$SCRIPTS/list-plugins.sh"` (recompute `SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"`
  fresh). If it prints a non-empty JSON array, use `AskUserQuestion` to let the user
  choose — one option per plugin (label = `name`, description = the manifest
  `description`) — and use the chosen entry's `path`. Only if it exits non-zero or
  returns `[]` (not in a marketplace / no plugins) fall back to asking in free text.
- Confirm the resolved directory is a plugin: `.claude-plugin/plugin.json` must
  exist. If not, stop and say so.

## 2. Guided intake — fill in what's missing

Decide first whether the change is **already fully specified** — i.e. there is real,
actionable change text after the plugin dir (not empty, not a placeholder). If so,
**skip this whole step** and go straight to step 3 (Plan) with that text, exactly as
before. Otherwise, gather what's missing — never re-asking anything a flag or the
invocation text already answered:

- **Change type.** If `--type=` was captured, use it and do **not** ask. Otherwise
  ask exactly one `AskUserQuestion` (single-select) with four options — **Add a
  feature**, **Change a behavior**, **Fix a bug**, **Remove a capability** (a short
  description each) — keeping the tool's built-in free-form option.
- **Specific suggestions.** Ground them in what the plugin actually is: read the
  resolved plugin's own `.claude-plugin/plugin.json`, `CONTEXT.md`, `README.md`, and
  its `commands/`, `agents/`, `skills/`, `scripts/` (whatever exists, if not already
  read this turn). Compose **3–5 plausible, concrete** suggestions specific to both
  the chosen change type **and** this particular plugin — never generic placeholders —
  and present them via a single-select `AskUserQuestion`, always keeping the built-in
  **"Other"** free-form option so the user can describe their own change instead.
- **Combine what's known.** Fold together any literal change text from the
  invocation, the flagged/answered change type, and the chosen or freely-typed
  suggestion into **one concrete change description**, then proceed to step 3 (Plan)
  with it.

## 3. Plan (delegate to the planner)

- Invoke the `edit-planner` agent (Task tool) with the plugin directory and the
  requested change. It returns a JSON plan: `summary`, `changeType`, `files[]`,
  `changelog`, `bumpLevel`, `templateDivergence`, `questions[]`. If it does not
  return one valid JSON object, ask it to try again.

## 4. Resolve unknowns — ask, don't guess

- If the plan has `questions`, ask them (use `AskUserQuestion` for discrete
  choices) and re-run the planner with the answers if they change the plan.

## 5. Confirm the plan — do NOT edit yet

- Present the plan: the files it will touch and how, the `[Unreleased]` entry, the
  version impact, and any `templateDivergence` note.
- **If this is a `--dry-run`:** label the plan you just presented as a **DRY RUN /
  PREVIEW**, state explicitly that **nothing on disk was or will be changed**,
  and tell the user the exact command to re-run **without** `--dry-run` to apply it.
  Then **STOP** — do not proceed to step 6 (apply), step 7 (verify), step 8
  (check-template.sh / update-changelog.sh / sync-version.sh), step 9 (reload hint),
  or the completed-work summary in step 10. The dry run ends here.
- **Otherwise:** get an explicit go-ahead before making any change, then continue.

## 6. Apply the edits

- Make exactly the edits in the approved plan, operating **only inside the target
  plugin's own directory**. Use Edit/Write. Never touch anything outside it.

## 7. Verify the edits landed

- Re-read (Read) **every** file in the plan's `files[]` and confirm the specific
  change it described is actually present — a semantic check, not just that the file
  parses. For a deletion, confirm the file or capability is really gone.
- If a change didn't land or landed wrong, fix it with Edit and re-check. If you
  cannot resolve it, stop and tell the user exactly what is missing before going on.
- Only continue once every planned change is confirmed.

## 8. Check, record, version — deterministic scripts

Run these with Bash and relay each script's output. Each Bash call is a fresh
shell, so recompute `SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"` every time.

1. `"$SCRIPTS/check-template.sh" <plugin-dir>` — structural validation **and**
   template-drift. If the structural check fails, fix what it reports (or surface
   it to the user) before continuing.
2. `"$SCRIPTS/update-changelog.sh" <plugin-dir> <category> "<bullet>"` — record the
   change under `[Unreleased]`, using the plan's `changelog.category` and `bullet`.
3. `"$SCRIPTS/sync-version.sh" <plugin-dir> <bumpLevel>` — advance the version the
   right way. It either hand-bumps a standalone plugin or, for a release-please
   plugin, prints the Conventional Commit to land; relay that guidance verbatim.

## 9. Reload hint

- `"$SCRIPTS/check-install-status.sh" <plugin-dir>` — if the plugin is installed in
  this session, relay its suggestion to run `/plugin update <name>` and
  `/reload-plugins` so the edits take effect.

## 10. Summary

Give the user a clear summary of the change:

- **Files** — each path touched and, in one line, what changed (as confirmed by the
  verify step in 7).
- **Changelog** — the `[Unreleased]` category and bullet that was recorded.
- **Version** — the new version (standalone) or the Conventional Commit to land
  (release-please-managed), from `sync-version.sh`.
- **Reload** — the `/plugin update` + `/reload-plugins` hint when the plugin is
  active in this session.

Throughout: ask when unsure, keep deterministic work in the scripts, prefer the
minimum-capable model for any new component, and never edit outside the target
plugin's directory.
