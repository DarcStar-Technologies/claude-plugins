---
description: Scaffold a new Claude Code plugin from a description — in this marketplace or standalone.
argument-hint: "[what the plugin should do]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

Create a new Claude Code plugin from the user's description. Delegate the
deterministic scaffolding to a shell script, prefer the minimum capable model,
and prompt the user for anything you can't confidently infer.

`$ARGUMENTS` is the user's description, plus any flags (e.g. a template version or
repo, or `--portable`).

Work through these steps in order.

## 1. Choose a mode

Each Bash call runs in a **fresh shell**, so recompute paths in every command.

- Find the repo root, if any:
  `ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"`.
- **Marketplace mode** — if `"$ROOT/scripts/new-plugin.sh"` and
  `"$ROOT/.claude-plugin/marketplace.json"` both exist, you're inside the DarcStar
  marketplace repo: scaffold **and register** the plugin there.
- **Portable mode** — otherwise, or if the user asked for a standalone plugin
  (`--portable`): use the bundled
  `"${CLAUDE_PLUGIN_ROOT}/scripts/forge-scaffold.sh"`, which creates a standalone
  plugin in the current directory and registers nothing.

Tell the user which mode you're in. If `$ARGUMENTS` has no description, ask what
the plugin should do before continuing.

## 2. Template source

- Marketplace mode always uses the repo's current `_template`.
- Portable mode resolves the template in this precedence (pass the user's choice
  through to the scaffolder in step 5):
  1. `--template-version <ver>` → the `_template-v<ver>` release tag,
  2. `--template-repo <owner/repo[@ref]>` → that repo,
  3. a local `./_template/` directory,
  4. the latest template from the DarcStar repo (the default).

## 3. Plan (delegate to the planner subagent)

- Use the `plugin-planner` agent (via the Task tool). Give it the description and,
  in marketplace mode, the repo root so it can read the conventions. In portable
  mode the repo files may be absent — tell it to plan from general Claude Code
  plugin knowledge.
- It returns a JSON plan: `name`, `description`, `keywords`, `components[]` (each
  with `type`, `file`, `responsibility`, `model`, `tools`), and `questions[]`. If
  it doesn't return a single valid JSON object, ask it to try again.

## 4. Resolve unknowns — ask, don't guess

- If the plan has `questions`, ask them (use `AskUserQuestion` for discrete
  choices) and incorporate the answers; re-run the planner if they change the plan.
- Present the final plan (name, components, model per component) and get the user's
  go-ahead before creating anything.

## 5. Scaffold deterministically

Pass the description as a single **single-quoted** argument so punctuation, quotes,
or `$` can't break the command.

- **Marketplace mode:**
  `"$ROOT/scripts/new-plugin.sh" <name> --description 'One clear sentence.'`
  — registers the plugin in the marketplace, release config, and provenance; never
  edit those by hand.
- **Portable mode:**
  `"${CLAUDE_PLUGIN_ROOT}/scripts/forge-scaffold.sh" <name> --description 'One clear sentence.'`
  plus any of `--out <dir>`, `--template-version <ver>`, `--template-repo <repo>`.
- If it fails because the destination already exists, ask for a different name.

## 6. Realize the plan

- The scaffolder copies example components from the template. Reconcile them with
  the plan, operating **only inside the new plugin's own directory**: rewrite the
  components in the plan, remove the examples that aren't, and create any missing
  ones. Never delete anything outside that directory.
- Write each component from the description and plan:
  - Set the planned **minimum-capable `model:`** on every agent/command.
  - Give each a least-privilege `tools` / `allowed-tools` list.
  - Put anything fully deterministic in a `scripts/*.sh` shell step, not a model.
- Update the new plugin's `CONTEXT.md`, `README.md`, and `plugin.json` keywords to
  describe the real plugin (the scaffolded docs are generic placeholders).

## 7. Validate

- **Marketplace mode:** run `"$ROOT/scripts/check-all.sh"` and fix what it reports.
- **Portable mode:** there is no `check-all.sh`; instead verify `plugin.json` is
  valid JSON (`jq empty`), the docs exist, and `shellcheck` any shell scripts.

## 8. Report

- Summarize what you created (path + components) and the next steps: flesh out the
  component bodies, and — in marketplace mode — commit with a Conventional Commit
  (e.g. `feat(<name>): ...`).

Throughout: prefer the minimum capable model, keep deterministic work in shell,
and never silently guess a requirement — ask.
