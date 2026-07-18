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
Both modes use the same scaffolder,
`"${CLAUDE_PLUGIN_ROOT}/scripts/forge-scaffold.sh"` — the only difference is
whether it registers the plugin.

- **Marketplace mode** — if `"$ROOT/.claude-plugin/marketplace.json"` exists, you
  are inside a marketplace repo: scaffold into `plugins/<name>` **and register** it
  by passing `--register "$ROOT"`.
- **Portable mode** — otherwise, or if the user asked for a standalone plugin
  (`--portable`): scaffold a standalone plugin in the current directory (no
  `--register`), registering nothing.

Tell the user which mode you're in.

**If `$ARGUMENTS` has no description, run a guided intake** instead of a bare
free-text ask (mirroring `/forge-template` and `/edit-plugin`). Skip this entirely
when a description was given — that flow is unchanged.

- **Which template?** Ask this **first** — a single-select `AskUserQuestion` grounded in
  the real reference templates: run `"$ROOT/scripts/list-templates.sh"` and skim each so
  the archetype options are concrete — e.g. a command-only suite (`command-suite`), a
  command + planner-agent + script mix (`default`), or a plan → confirm → apply workflow
  (`plan-confirm-apply`). `AskUserQuestion` allows at most **4** options — present all
  the templates when there are ≤4 (three today); if `templates/` ever holds more, offer
  a representative spread (there is no purpose captured yet to rank by) and let the
  built-in **"Other"** free-form option cover the rest (it is added for you — do not add
  your own). If the script isn't available (portable mode without this repo checked out),
  describe those same archetypes from general knowledge. **Record the
  chosen archetype as the authoritative template** — a deliberate pick is an explicit
  template request, so pass it to the planner in step 3 and as `--template <name>` in
  step 5 rather than letting the planner re-infer one.
- **What should the plugin do?** Then capture its **purpose** — the domain input `/forge`
  can't infer, which the planner builds the name, description, and components from. Ask
  the user in free text; never skip it.
- **Which components?** Optionally ask a second single-select `AskUserQuestion` with up
  to **4** concrete component-set suggestions for the chosen template (its built-in
  **"Other"** is likewise added for you).
- **Combine.** Fold the answers into one clear description **centered on the purpose**
  (the domain intent the planner names and shapes the plugin from) — the template and
  component set refine that purpose, they do not replace it. Then continue with the
  normal flow (template selection in step 2, the planner in step 3), carrying the
  authoritative template forward.

## 2. Template source

The marketplace ships several **reference templates** — the plugins under
`templates/` (a sibling of `plugins/`). Each contributes its component set
(commands/agents/skills/scripts) to the new plugin. List them to choose the best
fit:

- `"$ROOT/scripts/list-templates.sh"` (add `--json` for a machine-readable list).

Pick the template whose archetype matches what the plugin is — e.g.
`command-suite` for a plugin that is mainly a set of related slash commands, or
`default` for a general mix of command/agent/skill/script. The planner proposes
one in step 3; override it from the user's explicit request.

`--template <name>` selects **which** template (default `default`). The *source*
of that template is then resolved by mode:

- **Marketplace mode** — the template is the plugin of that name under `templates/`
  in this repo. Pass `--template <name>` (omit for `default`).
- **Portable mode** — resolve the named template's source in this precedence (pass
  the user's choice through to the scaffolder in step 5):
  1. `--template-version <ver>` → the `<name>-v<ver>` release tag,
  2. `--template-repo <owner/repo[@ref]>` → that repo,
  3. a local `./<name>/` directory,
  4. the latest `<name>` template from the DarcStar repo (the default).

## 3. Plan (delegate to the planner subagent)

- Use the `plugin-planner` agent (via the Task tool). Give it the description and,
  in marketplace mode, the repo root and the available templates (from step 2) so
  it can read the conventions and pick a template. In portable mode the repo files
  may be absent — tell it to plan from general Claude Code plugin knowledge and
  default the template to `default`. **If guided intake (step 1) selected an
  archetype, pass it as the authoritative template** so the plan uses it rather than
  re-inferring one.
- It returns a JSON plan: `name`, `description`, `keywords`, `template` (the
  best-fit template name), `components[]` (each with `type`, `file`,
  `responsibility`, `model`, `tools`), and `questions[]`. If it doesn't return a
  single valid JSON object, ask it to try again.

## 4. Resolve unknowns — ask, don't guess

- If the plan has `questions`, ask them (use `AskUserQuestion` for discrete
  choices) and incorporate the answers; re-run the planner if they change the plan.
- Present the final plan (name, components, model per component) and get the user's
  go-ahead before creating anything.

## 5. Scaffold deterministically

Pass the description as a single **single-quoted** argument so punctuation, quotes,
or `$` can't break the command.

Add `--template <name>` when the plan chose a template other than the default
`default`.

- **Marketplace mode:**
  `"${CLAUDE_PLUGIN_ROOT}/scripts/forge-scaffold.sh" <name> --description 'One clear sentence.' [--template <template>] --register "$ROOT"`
  — registers the plugin in the marketplace, release config, and provenance; never
  edit those by hand.
- **Portable mode:**
  `"${CLAUDE_PLUGIN_ROOT}/scripts/forge-scaffold.sh" <name> --description 'One clear sentence.'`
  plus any of `--template <name>`, `--out <dir>`, `--template-version <ver>`, `--template-repo <repo>`.
- If it fails because the destination already exists, ask for a different name.

## 6. Realize the plan

- The scaffolder copies example components from the template. Reconcile them with
  the plan, operating **only inside the new plugin's own directory**: rewrite the
  components in the plan, remove the examples that aren't, and create any missing
  ones. Never delete anything outside that directory.
- Write each component from the description and plan:
  - Set the planned **minimum-capable `model:`** on every agent/command.
  - Give each a least-privilege `tools` / `allowed-tools` list.
  - Put anything fully deterministic in a `scripts/*.sh` shell step, not a model. When you
    write shell, keep two hard-won pitfalls in mind:
    - **Never re-scan text you just inserted** in a string substitution. `${s//pat/repl}`
      treats `&` in `repl` specially (bash 5.2 `patsub_replacement`), and a `while [[ $s ==
      *tok* ]]` loop that reassigns `s` re-finds a token the inserted value contains — an
      infinite loop. Fill a placeholder by consuming the *original* segment-by-segment and
      concatenating (literal), not by repeatedly replacing in place.
    - **Lexical path checks aren't enough for writes** that take a caller-supplied path.
      Rejecting `..`/absolute paths doesn't stop a write from following a **symlink** — and
      a leaf `[[ -L "$dest" ]]` check misses a symlinked *ancestor* directory. Assert
      **physical containment**: the resolved parent (`cd "$(dirname "$dest")" && pwd -P`)
      must sit under the target dir's own `pwd -P`. Bundle a `bats` test for every script
      (the scaffolder wires one up).
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
