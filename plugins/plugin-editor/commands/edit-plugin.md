---
description: Modify an existing plugin — add a feature, change behavior, fix a bug, or remove a capability — with clarifying questions, template checks, changelog + version updates, and a reload hint.
argument-hint: "<plugin-dir> — <what to change>"
allowed-tools: Read, Grep, Glob, Edit, Write, Bash, Task, AskUserQuestion
model: sonnet
---

Modify an existing Claude Code plugin safely. Work through these steps in order and
**never edit anything until the user approves the plan.**

`$ARGUMENTS` is the target plugin directory followed by the change to make.

## 1. Locate the plugin

- If `$ARGUMENTS` names a directory, use it. Otherwise, if the current directory
  contains `.claude-plugin/plugin.json`, use that.
- If neither gives a target, **offer a picker** instead of guessing: run
  `"$SCRIPTS/list-plugins.sh"` (recompute `SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"`
  fresh). If it prints a non-empty JSON array, use `AskUserQuestion` to let the user
  choose — one option per plugin (label = `name`, description = the manifest
  `description`) — and use the chosen entry's `path`. Only if it exits non-zero or
  returns `[]` (not in a marketplace / no plugins) fall back to asking in free text.
- Confirm the resolved directory is a plugin: `.claude-plugin/plugin.json` must
  exist. If not, stop and say so.

## 2. Plan (delegate to the planner)

- Invoke the `edit-planner` agent (Task tool) with the plugin directory and the
  requested change. It returns a JSON plan: `summary`, `changeType`, `files[]`,
  `changelog`, `bumpLevel`, `templateDivergence`, `questions[]`. If it does not
  return one valid JSON object, ask it to try again.

## 3. Resolve unknowns — ask, don't guess

- If the plan has `questions`, ask them (use `AskUserQuestion` for discrete
  choices) and re-run the planner with the answers if they change the plan.

## 4. Confirm the plan — do NOT edit yet

- Present the plan: the files it will touch and how, the `[Unreleased]` entry, the
  version impact, and any `templateDivergence` note. Get an explicit go-ahead
  before making any change.

## 5. Apply the edits

- Make exactly the edits in the approved plan, operating **only inside the target
  plugin's own directory**. Use Edit/Write. Never touch anything outside it.

## 6. Verify the edits landed

- Re-read (Read) **every** file in the plan's `files[]` and confirm the specific
  change it described is actually present — a semantic check, not just that the file
  parses. For a deletion, confirm the file or capability is really gone.
- If a change didn't land or landed wrong, fix it with Edit and re-check. If you
  cannot resolve it, stop and tell the user exactly what is missing before going on.
- Only continue once every planned change is confirmed.

## 7. Check, record, version — deterministic scripts

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

## 8. Reload hint

- `"$SCRIPTS/check-install-status.sh" <plugin-dir>` — if the plugin is installed in
  this session, relay its suggestion to run `/plugin update <name>` and
  `/reload-plugins` so the edits take effect.

## 9. Summary

Give the user a clear summary of the change:

- **Files** — each path touched and, in one line, what changed (as confirmed by the
  verify step in 6).
- **Changelog** — the `[Unreleased]` category and bullet that was recorded.
- **Version** — the new version (standalone) or the Conventional Commit to land
  (release-please-managed), from `sync-version.sh`.
- **Reload** — the `/plugin update` + `/reload-plugins` hint when the plugin is
  active in this session.

Throughout: ask when unsure, keep deterministic work in the scripts, prefer the
minimum-capable model for any new component, and never edit outside the target
plugin's directory.
