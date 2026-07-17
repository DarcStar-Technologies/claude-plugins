---
description: Upgrade or downgrade an already-scaffolded plugin to a different version of the reference template it was created from, via a plan-confirm-apply flow.
argument-hint: "[--dry-run] [<plugin-dir>] [<version>|latest]"
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion, Edit
model: sonnet
---

Retarget an already-scaffolded plugin to a **different version of the template it was
created from** — upgrade or downgrade. This is the **plan → confirm → apply** archetype:
work through the steps in order and **never change any file until the user approves the
plan.** It mutates the plugin's own files, so the confirm gate is mandatory.

`$ARGUMENTS` may contain, in any order: `--dry-run` and a `<plugin-dir>`. A trailing
token that is a semver (e.g. `0.3.0`) or the word `latest` is the **target version**.
All are optional — steps 1–2 fill in the rest.

Each Bash call is a fresh shell; recompute `S="${CLAUDE_PLUGIN_ROOT}/scripts"` every time.

## 1. Resolve the target plugin

- **`--dry-run`** → preview the plan and stop, touching nothing (step 6).
- **Resolve the plugin dir:** if a `<plugin-dir>` was given, use it. Otherwise offer a
  **picker**: run `"$S/discover-targets.sh"`. If it prints a non-empty JSON array, use
  `AskUserQuestion` (one option per entry — label `name`, description `description`;
  4 max, rely on "Other" beyond that) and use the chosen `path`. If it exits non-zero
  or prints `[]`, tell the user no retargetable plugin was found and stop.
- Confirm the dir has `.claude-plugin/scaffold.json` with a `template` and
  `templateVersion` — that provenance is what retargeting compares against. If it's
  missing, stop: the plugin wasn't scaffolded by plugin-forge, so there is nothing to
  retarget. Read `template`, `templateVersion` (the **current/base** version), and
  `source` from it, and the plugin's `name`/`description` from `plugin.json`.

## 2. Resolve the target version

- If a version token was given, use it (a semver, or `latest`).
- Otherwise ask with `AskUserQuestion`: offer `latest` plus a couple of concrete nearby
  versions if you can infer them, always keeping "Other" for the user to type an exact
  version. **Both directions are valid** — a version *below* the current one is a
  downgrade, which is supported.
- Refuse **switching templates**: this command only changes the *version* of the
  recorded template. If the user wants a different template entirely, tell them to
  re-scaffold instead.

## 3. Materialize both versions and diff (deterministic)

Run these and pass their JSON forward:

1. `"$S/resolve-template-version.sh" <template> <base-version> --from <plugin-dir> --source <source>`
   — materializes the version the plugin is currently on (`{dir, cleanupPath, …}`).
2. `"$S/resolve-template-version.sh" <template> <target-version> --from <plugin-dir> --source <source>`
   — materializes the requested target. If either can't resolve, relay the error and stop.
3. `"$S/diff-components.sh" --base <base.dir> --current <plugin-dir> --target <target.dir> --name <name> --desc <description>`
   — a JSON array classifying every `commands/agents/skills/scripts` file as
   `update` / `add` / `delete` / `keep` / `unchanged` / `conflict` (see the script header).

Remember each result's `cleanupPath`; `rm -rf` any non-null ones once you're done (step 7).

## 4. Plan (delegate to the planner)

- Invoke the `scaffold-retarget-planner` agent (Task tool) with the plugin dir, the base
  and target versions, and the diff JSON. It returns a plan (`summary`, `actions[]` — each
  a `{path, action}` decision — `risks[]`, `questions[]`). Every `conflict` from the diff
  must come back as a `question` or a `risk`, never a silently-chosen winner.

## 5. Resolve unknowns — ask, don't guess

- If the plan has `questions` (typically conflict resolutions — keep mine / take the
  template's), ask them with `AskUserQuestion` and fold the answers into the decisions.

## 6. Confirm the plan — do NOT change anything yet

- Present it: base → target version, each file and its action, and any `risks`.
- **If `--dry-run`:** label it a **DRY RUN / PREVIEW**, state that nothing was or will be
  changed, give the exact command to re-run without `--dry-run`, and **STOP** (no step 7–8).
- **Otherwise:** get an explicit go-ahead, then continue.

## 7. Apply (deterministic) and verify

- `"$S/apply-retarget.sh" --plugin <plugin-dir> --target <target.dir> --name <name>
  --desc <description> --to-version <target-version> --from-version <base-version>
  --decisions '<approved decisions JSON>'` — it renders `update`/`add` files with the
  plugin's OWN identity, deletes `delete` files, updates `scaffold.json`'s
  `templateVersion`, and adds a CHANGELOG `[Unreleased]` entry. It writes only inside the
  plugin dir.
- **Verify:** re-read each changed file and confirm it matches the target (identity
  preserved — no `{{NAME}}`/`{{DESC}}` left, `plugin.json` name/description untouched),
  and that `scaffold.json.templateVersion` is now the target. Use Edit to repair a
  mismatch; never hand-edit component bodies wholesale. Then `rm -rf` any `cleanupPath`s.

## 8. Summary

Report: base → target version and direction (upgrade/downgrade), each file changed and
how, any residual risks, and the reminder that this did **not** bump the plugin's
`plugin.json` version — release-please does that from the resulting Conventional Commit,
so land one (e.g. `chore(<plugin>): retarget to <template> v<target>`).

Throughout: keep deterministic work in the scripts, ask when a conflict is genuinely
ambiguous, and never change anything outside the resolved plugin directory.
