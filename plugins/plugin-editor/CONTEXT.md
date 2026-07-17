# plugin-editor — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Make modifying an existing plugin safe and routine. A change request ("add a
`--quiet` flag", "remove the legacy command") is turned into a reviewed plan,
applied, and then run through the housekeeping every plugin edit needs: a
template-conformance check, a changelog entry, the right version bump, and a reload
hint if the plugin is live in the session.

## Mental model

**The model does the irreducible reasoning; scripts do everything deterministic.**
Interpreting a natural-language request, editing code, and judging whether a change
diverges from the plugin's template genuinely need a model. Everything else —
inserting a changelog bullet, deciding release-please vs. hand-bump, detecting an
active install — is a tested shell script. The command is the conductor:

```text
/edit-plugin [--dry-run] [--plugin=<dir>] [--type=add|change|fix|remove] [<dir>] [— <change>]
   │
   ├─ no <dir>? list-plugins.sh         → user picks from the marketplace's plugins
   ├─ change not fully described?       → guided intake: change-type Q (skipped if
   │                                       --type=), then plugin-specific suggestions
   │                                       (AskUserQuestion, "Other" always available)
   ├─ edit-planner (agent, read-only)   → a concrete plan + clarifying questions
   ├─ confirm with the user             → NOTHING is edited before this
   │     └─ --dry-run? show the plan as a preview and STOP here (disk untouched)
   ├─ apply edits (only inside <dir>)
   ├─ verify the edits landed           → re-read + semantic check each planned change
   ├─ resolve edit-kit                  → EK = edit-kit-path.sh (the shared toolkit)
   ├─ check-template.sh                 → drift (own) + structure via EK/check-structure.sh
   ├─ EK/update-changelog.sh            → [Unreleased] entry
   ├─ EK/sync-version.sh                → bump / commit guidance
   ├─ new scripts/*.sh in the plan?     → EK/scaffold-test.sh writes a bundled bats
   │                                       stub per new script (idempotent)
   ├─ EK/verify-repo.sh                 → advisory cross-checks: repo check-all.sh +
   │                                       plugin tests (hard only on own bundled tests)
   └─ check-install-status.sh           → reload hint
```

The **plan → confirm → apply** ordering is the core safety property: the command
never edits until the user approves.

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `commands/edit-plugin.md` | Slash command (`sonnet`) | Orchestrates the flow; applies edits; runs the scripts. |
| `agents/edit-planner.md` | Subagent (`sonnet`, read-only) | Interprets the request; asks clarifying questions; returns the plan. |
| `scripts/list-plugins.sh` | Shell | Discover the marketplace's plugins for the picker when no target is given. |
| `scripts/check-template.sh` | Shell | Template-drift check (reuse of `scaffold-upgrade`), plus structure **delegated to edit-kit's `check-structure.sh`**. |
| `scripts/edit-kit-path.sh` | Shell | Resolve the `edit-kit` scripts dir at run time (`$EDIT_KIT_DIR` → marketplace ancestor → `PATH`). |
| `scripts/check-install-status.sh` | Shell | Is the plugin installed/stale → reload hint. |

The generic edit-flow scripts — `update-changelog.sh`, `sync-version.sh`,
`scaffold-test.sh`, `verify-repo.sh`, `check-structure.sh`, `lib/plan-paths.sh` — are
**not** here: they live in the [`edit-kit`](../edit-kit/) provider plugin and are
resolved at run time via `edit-kit-path.sh`, shared with `template-editor`.

## Model selection

Both the command and the planner use `sonnet` — interpreting a change request and
editing plugin code is moderate reasoning, and `haiku` is too weak for reliable
code edits while `opus` is more than it needs (escalate to `opus` only for a
genuinely intricate change). Everything mechanical lives in `scripts/` at **no**
model cost.

## Reuse, resolved at run time (no vendored copies)

- **`edit-kit`** — the generic edit-flow scripts (`update-changelog.sh`,
  `sync-version.sh`, `scaffold-test.sh`, `verify-repo.sh`, `check-structure.sh`) live in
  the `edit-kit` provider plugin and are resolved via `edit-kit-path.sh`
  (`$EDIT_KIT_DIR` → marketplace ancestor → `PATH`). `template-editor` uses the same
  toolkit, so there is one canonical implementation. edit-kit is also a **bare-string
  `dependencies` entry in `plugin.json`**, so Claude Code auto-installs it (and,
  transitively, `semver`) when plugin-editor is installed — and disables plugin-editor if
  it can't; `edit-kit-path.sh` then just *locates* the installed toolkit at run time (and
  finds the sibling `plugins/edit-kit` when running from the repo checkout).
- **`semver`** — `edit-kit`'s `sync-version.sh` bumps standalone plugins with `semver.sh`.
- **`scaffold-upgrade`** — `check-template.sh` calls `check-upgrade.sh` for drift.
- **the repo's own checks** — `edit-kit`'s `verify-repo.sh` shells out to the
  marketplace's `scripts/check-all.sh` and `bats`, located by walking up from the plugin
  directory; a missing one is skipped with a clear note — never a failure — and check-all
  / centralized-test failures are advisory `WARNING`s (see the gotcha below).

Each is found at run time (`$EDIT_KIT_DIR` / `$SEMVER_BIN` / `$CHECK_UPGRADE_BIN` → a
marketplace ancestor → `PATH`), the same pattern the rest of the marketplace uses, so
there is one source of truth for each.

## Gotchas

- **Never edit outside the target plugin's directory.** The command is scoped to
  `<plugin-dir>`; the planner is read-only.
- **`--dry-run` is a directive-segment flag** (recognized before the `—` separator per
  the rule below; a `--dry-run` inside the change description is literal — otherwise
  "add a `--dry-run` flag to X" would misfire). When set, the command stops immediately
  after presenting the plan — before any of check-template.sh / update-changelog.sh /
  sync-version.sh / verify-repo.sh / check-install-status.sh run — so the plugin's
  directory and disk state are left untouched.
- **Post-apply verification is scoped and advisory.** `verify-repo.sh` (step 8) adds
  cross-checks on top of check-template.sh's hard, plugin-scoped structural check.
  Because `/edit-plugin` only edits inside the plugin dir, anything it can't fix
  in-bounds must not falsely block a correct edit: the repo-wide `check-all.sh` (run
  only when a marketplace ancestor is found) and the repo's **centralized**
  `scripts/tests/<name>.bats` for a touched script are advisory `WARNING`s, never hard
  failures — a repo-wide failure is usually pre-existing breakage in another plugin; a
  centralized-test failure usually means a behavior change needs a follow-up test
  update outside this plugin. The **only** hard failure verify-repo adds is the
  plugin's **own bundled** `scripts/tests/*.bats` (in-bounds to fix). A removed script
  skips its centralized test.
- **New scripts get a bundled test stub, in-bounds only.** When the approved plan
  *creates* a new top-level `scripts/*.sh`, step 8 runs `scaffold-test.sh` to write a
  `scripts/tests/<name>.bats` stub for it — always inside the **target plugin's own**
  `scripts/tests/`, never the marketplace's centralized `scripts/tests/` (out of bounds
  for this command). That keeps it in-bounds *and* gives the new script a home in the
  plugin's own (hard-checked) bundled suite that verify-repo.sh discovers. The generated
  stub is a **skipped placeholder**: it does *not* invoke the script (an auto-generated
  no-argument run could hang on a stdin read or fire a side effect) and makes **no** smoke
  assertion (asserting output would wrongly hard-fail a legitimately-silent script under
  verify-repo.sh's bundled-tests check) — so it passes as a skip and never blocks a
  correct edit. The author replaces it with real assertions and removes the skip; until
  then it is a scaffold, not actual coverage. It fires only for newly **created**
  top-level `scripts/*.sh` (not modified scripts, not a nested `scripts/lib/*` path) and
  is **idempotent** (an existing or hand-written stub is left untouched). Both this and
  verify-repo.sh live in **edit-kit** and share its `lib/plan-paths.sh` normalizer, so the
  two classify the same path identically.
- **Flags live in the "directive segment".** All three flags (`--dry-run`,
  `--plugin=<dir>`, `--type=add|change|fix|remove`) are recognized anywhere **before
  the `—` change-description separator**, alongside the plugin dir, in any order; when
  there is no separator they must be **leading** (before `<dir>`). Either way a
  flag-looking token *inside* the change description stays literal (so "add a
  `--dry-run` flag to X" doesn't misfire). They let the flow **resume from whatever is
  already known**: a known plugin (positional `<dir>` or `--plugin=`) skips the picker,
  a known `--type=` skips the change-type question **and** is passed to the planner as
  the authoritative change type (even when the change is already fully described, so an
  explicit `--type=` is never silently re-inferred), and an already-fully-described
  change skips the guided-intake questions entirely. `--plugin=` wins over a positional
  `<dir>`; the redundant positional token is dropped so it can't leak into the change.
- **Versioning is context-aware.** In this release-please repo you do **not**
  hand-bump `plugin.json` — `sync-version.sh` detects the config and tells you the
  Conventional Commit to land instead. Standalone plugins get a real bump.
- **Portable dependencies.** For standalone use, `semver` / `scaffold-upgrade` must
  be reachable (`$SEMVER_BIN` / `$CHECK_UPGRADE_BIN` or on `PATH`); the scripts say
  so clearly when they aren't.
- **`installed_plugins.json` is read-only input** (path overridable via
  `$INSTALLED_PLUGINS_JSON` for tests) — the plugin never writes Claude Code config.
