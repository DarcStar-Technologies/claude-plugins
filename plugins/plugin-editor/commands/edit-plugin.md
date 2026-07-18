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
flags `--dry-run`, `--plugin=<dir>`, and `--type=add|change|fix|remove` may appear
before the change description (see below).

## 1. Locate the plugin

- **First, split off the change description, then parse flags.** Everything after the
  `—` change-description separator (however the user typed it) is the **literal change
  description** — never scan it for flags. What precedes it is the **directive
  segment**: zero or more flags plus an optional `<plugin-dir>`, in any order. If
  `$ARGUMENTS` has **no** separator, recognize flags only as **leading tokens** (before
  `<plugin-dir>`) and treat everything after `<plugin-dir>` as the change description.
  Either way, a flag-looking token that is really content (e.g. "add a `--dry-run` flag
  to …", "fix the `--type=` parser") stays literal instead of misfiring.
- **Recognize these flags** in the directive segment — strip each one and remember it:
  - `--dry-run` → this is a **dry run**: you will preview the plan and stop, never
    touching disk (see step 5).
  - `--plugin=<dir>` → the plugin directory is `<dir>`, and it is **authoritative**:
    skip the resolution below, and if a positional `<plugin-dir>` was *also* given,
    drop that redundant token so it can't leak into the change description.
  - `--type=<...>` → the change type is known; carry it forward as the **authoritative**
    change type — used in step 2 and passed to the planner in step 3 even when guided
    intake is skipped.
- **Resolve the plugin directory** (skip if `--plugin=` already supplied one): if the
  directive segment names a directory, use it. Otherwise, if the current directory
  contains `.claude-plugin/plugin.json`, use that.
- If neither gives a target, **offer a picker** instead of guessing: run
  `"$SCRIPTS/list-plugins.sh"` (recompute `SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"`
  fresh). If it prints a non-empty JSON array, use `AskUserQuestion` to let the user
  choose — one option per plugin (label = `name`, description = the manifest
  `description`) — and use the chosen entry's `path`. Only if it exits non-zero or
  returns `[]` (not in a marketplace / no plugins) fall back to asking in free text.
- Confirm the resolved directory is a plugin: `.claude-plugin/plugin.json` must
  exist. If not, stop and say so.

## 2. Guided intake — fill in what's missing

The **change description** is whatever change text remains after the flags and the
plugin dir are stripped. Judge whether it is **already fully specified** — real,
actionable change text (not empty, not a placeholder):

- **If it is fully specified:** skip the intake questions and go straight to step 3
  (Plan). Still carry any captured `--type=` forward as the authoritative change type
  (step 3) — do not let the planner re-infer the type from the prose.
- **If it is not:** gather what's missing — never re-asking anything a flag or the
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
  requested change — plus, when `--type=` was captured, the **authoritative change
  type**, so the plan's `changeType`, `changelog.category`, and `bumpLevel` reflect the
  user's stated intent rather than a re-inference from the prose. It returns a JSON
  plan: `summary`, `changeType`, `files[]`, `changelog`, `bumpLevel`,
  `templateDivergence`, `questions[]`. If it does not return one valid JSON object, ask
  it to try again.

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
  (check-template.sh / update-changelog.sh / sync-version.sh / scaffold-test.sh /
  verify-repo.sh — none of which run, so no changelog entry, version bump, or
  scaffolded test stub is written), step 9 (reload hint), or the completed-work
  summary in step 10. The dry run ends here.
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

## 8. Check, record, version, verify — deterministic scripts

Run these with Bash and relay each script's output. Each Bash call is a fresh
shell, so recompute `SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"` every time. The generic
edit-flow scripts live in the **`edit-kit`** provider plugin (not here) — resolve its
scripts dir with `EK="$("$SCRIPTS/provider-path.sh" edit-kit check-structure.sh update-changelog.sh sync-version.sh scaffold-test.sh verify-repo.sh lib/plan-paths.sh --from <plugin-dir>)"` and, since each Bash
call is a fresh shell, **recompute `EK` (like `SCRIPTS`) in every call that uses it**. If
resolution fails, tell the user to install the `edit-kit` plugin (or set `EDIT_KIT_DIR`)
and stop.

1. `"$SCRIPTS/check-template.sh" <plugin-dir>` — structural validation (delegated to
   edit-kit's `check-structure.sh`) **and** template-drift (plugin-editor's own). If the
   structural check fails, fix what it reports (or surface it to the user) before
   continuing.
2. `"$EK/update-changelog.sh" <plugin-dir> <category> "<bullet>"` — record the
   change under `[Unreleased]`, using the plan's `changelog.category` and `bullet`.
3. `"$EK/sync-version.sh" <plugin-dir> <bumpLevel>` — advance the version the
   right way. It either hand-bumps a standalone plugin or, for a release-please
   plugin, prints the Conventional Commit to land; relay that guidance verbatim.
4. **Only if the plan created any new `scripts/*.sh`:** for each `files[]` entry with
   `action: "create"` whose `path` is a new **top-level** `scripts/<name>.sh` (matches
   `scripts/*.sh` with no further `/` — never a nested `scripts/lib/*` path, mirroring
   verify-repo.sh's own scope), run `"$EK/scaffold-test.sh" <plugin-dir> <path...>`
   (pass every such new-script path in **one** call) to write a bundled
   `scripts/tests/<name>.bats` stub for each. It is **idempotent** — an existing stub is
   left untouched — so relay its output and continue even when every path was already
   scaffolded. **On a non-zero exit** (a passed path's script isn't present under the
   plugin dir — e.g. a mis-tagged path), fix the path or the applied edit (step 6/7) and
   re-run so the new script gets its bundled stub before you finish. **Skip this item
   entirely when the plan created no new `scripts/*.sh`.** It runs **before**
   verify-repo.sh so that script picks up the new stub(s). Each stub is a **skipped
   placeholder** — it gives the script a bundled test file to flesh out; it does not
   itself exercise the script, so it never blocks a correct edit.
5. `"$EK/verify-repo.sh" <plugin-dir> <files...>` — post-apply cross-checks.
   Pass every path from the plan's `files[]` as `<files...>`. On top of
   check-template.sh (which already hard-validates the plugin's own structure and
   shellchecks its scripts), it runs the repo's `scripts/check-all.sh` (in a
   marketplace) and the plugin's `bats` tests. It is **scoped and advisory**: because
   this command only edits inside the plugin dir, it hard-fails (exit non-zero) **only**
   on the plugin's own bundled `scripts/tests/*.bats`, which are in-bounds to fix.
   Repo-wide `check-all.sh` failures and the repo's centralized
   `scripts/tests/<name>.bats` are surfaced as **`WARNING:` lines**, never blocks (they
   may be pre-existing breakage elsewhere, or a behavior change that needs a follow-up
   test update outside this plugin). **On a non-zero exit**, fix the edit (step 6/7) and
   re-check before finishing. **Relay any `WARNING:` lines** to the user as advisories
   to review before merging — they do not block steps 9–10.

## 9. Reload hint

- `"$SCRIPTS/check-install-status.sh" <plugin-dir>` — if the plugin is installed in
  this session, relay its suggestion to run `/plugin update <name>` and
  `/reload-plugins` so the edits take effect.

## 10. Summary

Give the user a clear summary of the change:

- **Files** — each path touched and, in one line, what changed (as confirmed by the
  verify step in 7).
- **Scaffolded tests** — any bundled `scripts/tests/<name>.bats` stub `scaffold-test.sh`
  wrote for a newly created script, noting it is a placeholder smoke test to flesh out
  with real assertions.
- **Changelog** — the `[Unreleased]` category and bullet that was recorded.
- **Version** — the new version (standalone) or the Conventional Commit to land
  (release-please-managed), from `sync-version.sh`.
- **Reload** — the `/plugin update` + `/reload-plugins` hint when the plugin is
  active in this session.

Throughout: ask when unsure, keep deterministic work in the scripts, prefer the
minimum-capable model for any new component, and never edit outside the target
plugin's directory.
