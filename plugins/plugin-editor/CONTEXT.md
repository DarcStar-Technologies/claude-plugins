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
/edit-plugin <dir> — <change>
   │
   ├─ edit-planner (agent, read-only)   → a concrete plan + clarifying questions
   ├─ confirm with the user             → NOTHING is edited before this
   ├─ apply edits (only inside <dir>)
   ├─ check-template.sh                 → structure + template drift
   ├─ update-changelog.sh               → [Unreleased] entry
   ├─ sync-version.sh                   → bump / commit guidance
   └─ check-install-status.sh           → reload hint
```

The **plan → confirm → apply** ordering is the core safety property: the command
never edits until the user approves.

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `commands/edit-plugin.md` | Slash command (`sonnet`) | Orchestrates the flow; applies edits; runs the scripts. |
| `agents/edit-planner.md` | Subagent (`sonnet`, read-only) | Interprets the request; asks clarifying questions; returns the plan. |
| `scripts/check-template.sh` | Shell | Structural validators + reuse of `scaffold-upgrade` for template drift. |
| `scripts/update-changelog.sh` | Shell | Insert a bullet under `[Unreleased] > ### <category>`. |
| `scripts/sync-version.sh` | Shell | Context-aware versioning (release-please vs. standalone). |
| `scripts/check-install-status.sh` | Shell | Is the plugin installed/stale → reload hint. |

## Model selection

Both the command and the planner use `sonnet` — interpreting a change request and
editing plugin code is moderate reasoning, and `haiku` is too weak for reliable
code edits while `opus` is more than it needs (escalate to `opus` only for a
genuinely intricate change). Everything mechanical lives in `scripts/` at **no**
model cost.

## Reuse, resolved at run time (no vendored copies)

- **`semver`** — `sync-version.sh` bumps standalone plugins with `semver.sh`.
- **`scaffold-upgrade`** — `check-template.sh` calls `check-upgrade.sh` for drift.

Both are found at run time (`$SEMVER_BIN` / `$CHECK_UPGRADE_BIN` → a marketplace
ancestor → `PATH`), the same pattern the rest of the marketplace uses, so there is
one source of truth for each.

## Gotchas

- **Never edit outside the target plugin's directory.** The command is scoped to
  `<plugin-dir>`; the planner is read-only.
- **Versioning is context-aware.** In this release-please repo you do **not**
  hand-bump `plugin.json` — `sync-version.sh` detects the config and tells you the
  Conventional Commit to land instead. Standalone plugins get a real bump.
- **Portable dependencies.** For standalone use, `semver` / `scaffold-upgrade` must
  be reachable (`$SEMVER_BIN` / `$CHECK_UPGRADE_BIN` or on `PATH`); the scripts say
  so clearly when they aren't.
- **`installed_plugins.json` is read-only input** (path overridable via
  `$INSTALLED_PLUGINS_JSON` for tests) — the plugin never writes Claude Code config.
