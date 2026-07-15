---
description: Scaffold a new marketplace plugin from a natural-language description.
argument-hint: "[what the plugin should do]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

Create a new plugin for this marketplace from the user's description. Delegate
all deterministic work to the repo's scripts, and prompt the user for anything
that can't be confidently inferred.

`$ARGUMENTS` is the user's description of the plugin they want.

Work through these steps in order.

## 1. Establish context

- Confirm you are inside a checkout of the `claude-plugins` marketplace: run
  `git rev-parse --show-toplevel` and treat that as `$ROOT`. If
  `$ROOT/scripts/new-plugin.sh` does not exist, stop and tell the user this
  command must be run from the marketplace repository.
- Read the current template version:
  `jq -r '.version' "$ROOT/plugins/_template/.claude-plugin/plugin.json"`. This is
  the default template version.

## 2. Handle the requested template version

- By default, scaffold from the current template (`_template`, current version).
- If the user asked for a **specific** template version, note that only the
  current version is supported today (older-version resolution is a roadmap item;
  see this plugin's `CONTEXT.md`). Tell the user, and continue with the current
  version only after they agree.
- If `$ARGUMENTS` is empty, ask the user what the plugin should do before going on.

## 3. Plan (delegate to the planner subagent)

- Use the `plugin-planner` agent (via the Task tool). Pass it **both** the repo
  root `$ROOT` (so it can read files regardless of the working directory) and the
  description. It returns a JSON plan: `name`, `description`, `keywords`,
  `components[]` (each with `type`, `file`, `responsibility`, `model`, `tools`),
  and `questions[]`. If it does not return a single valid JSON object, ask it to
  try again rather than proceeding on a malformed plan.

## 4. Resolve unknowns — ask, don't guess

- If the plan has any `questions`, ask the user those questions (use
  `AskUserQuestion` for discrete choices). Incorporate the answers.
- Re-run the planner if the answers materially change the plan.
- Present the final plan (name, components, model per component) and get the
  user's go-ahead before creating anything.

## 5. Scaffold deterministically

- Run `"$ROOT/scripts/new-plugin.sh"` with the plan's name and description. Pass
  the description as a single **single-quoted** argument so punctuation, quotes,
  or `$` in it can't break the command or be interpreted by the shell:
  `"$ROOT/scripts/new-plugin.sh" <name> --description 'One clear sentence.'`
- If it fails because the plugin already exists, ask the user for a different name
  and retry.
- This registers the plugin in the marketplace, release config, and provenance —
  do not edit those files by hand.

## 6. Realize the plan

- `new-plugin.sh` copies the `_template` example components. Reconcile them with
  the plan: keep and rewrite the components that are in the plan, delete the ones
  that aren't, and create any planned components that are missing.
- Write each component from the description and the plan:
  - Set the planned **minimum-capable `model:`** on every agent/command.
  - Give each agent/command a least-privilege `tools` / `allowed-tools` list.
  - Put anything fully deterministic in a `scripts/*.sh` shell step, not a model.
- Update the new plugin's `CONTEXT.md`, `README.md`, and `plugin.json` keywords to
  describe the real plugin (the scaffolded versions are generic placeholders).

## 7. Validate

- Run `"$ROOT/scripts/check-all.sh"` and fix anything it reports until it passes.
- If the plugin ships shell scripts, run `shellcheck` on them.

## 8. Report

- Summarize what you created (path + component list), and give the next steps:
  flesh out the component bodies, run `scripts/check-all.sh`, and commit with a
  Conventional Commit (e.g. `feat(<name>): ...`).

Throughout: prefer the minimum capable model, keep deterministic work in shell,
and never silently guess a requirement — ask.
