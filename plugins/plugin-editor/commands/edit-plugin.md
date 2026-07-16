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

- Determine the target plugin directory from `$ARGUMENTS` (default to the current
  directory if it contains `.claude-plugin/plugin.json`). If you can't tell which
  plugin is meant, ask.
- Confirm it is a plugin: `.claude-plugin/plugin.json` must exist. If not, stop and
  say so.

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

## 6. Check, record, version — deterministic scripts

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

## 7. Reload hint

- `"$SCRIPTS/check-install-status.sh" <plugin-dir>` — if the plugin is installed in
  this session, relay its suggestion to run `/plugin update <name>` and
  `/reload-plugins` so the edits take effect.

## 8. Report

- Summarize what changed (files, the changelog entry, the version guidance) and the
  next steps: in a release-please repo, the Conventional Commit to land; standalone,
  the new version; plus the reload hint when the plugin is active.

Throughout: ask when unsure, keep deterministic work in the scripts, prefer the
minimum-capable model for any new component, and never edit outside the target
plugin's directory.
