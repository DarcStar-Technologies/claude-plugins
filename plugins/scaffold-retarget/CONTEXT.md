# scaffold-retarget — Context

> Orientation for humans and AI assistants working on this plugin. It explains
> the *why* and the non-obvious concepts. Keep it current as the plugin evolves.

## Purpose

Upgrade **or downgrade** an already-scaffolded plugin to a different version of the
reference template it was created from, via a plan → confirm → apply flow. It is the
**mutating companion** to the read-only [`scaffold-upgrade`](../scaffold-upgrade/): where
that plugin only *reports* whether a plugin is behind its template, this one *applies* a
version change and updates the plugin's provenance.

## Mental model

A scaffolded plugin records its origin in `.claude-plugin/scaffold.json` (`template`,
`templateVersion`, `source`). Retargeting is a **3-way merge**, the same shape as `git
merge`, over the plugin's component files (`commands/agents/skills/scripts` only):

- **base** = the template at the version the plugin is currently on;
- **current** = the plugin's files now;
- **target** = the template at the requested version.

Because a template's files carry `{{NAME}}`/`{{DESC}}` placeholders while the plugin's
files have them substituted, base/target are **rendered with the plugin's own identity**
before comparison. Per file the diff yields `update` (template advanced, you didn't touch
it → take target), `keep` (only you changed it), `add`/`delete`, `unchanged`, or
`conflict` (both diverged → the user decides at the confirm gate). Apply re-renders the
chosen template files with the plugin's identity, updates `scaffold.json`, and records a
CHANGELOG entry — **never** touching `plugin.json`'s name/description.

```text
/scaffold-retarget [--dry-run] [<plugin-dir>] [<version>|latest]
   ├─ resolve plugin (discover-targets.sh; must have scaffold.json)
   ├─ resolve target version (+ base version) → resolve-template-version.sh ×2
   ├─ 3-way classify → diff-components.sh
   ├─ plan → scaffold-retarget-planner (read-only; surfaces conflicts as questions)
   ├─ validate plan shape → plan-kit's validate-plan.sh (via plan-kit-path.sh)
   ├─ confirm (nothing changes before this)
   └─ apply-retarget.sh → files + scaffold.json + CHANGELOG, inside the plugin only
```

## Components

| Path | Type | Model | Responsibility |
| ---- | ---- | ----- | -------------- |
| `commands/scaffold-retarget.md` | Command | `sonnet` | Orchestrates the flow; resolves plugin + versions; runs the scripts; gates on confirmation. |
| `agents/scaffold-retarget-planner.md` | Subagent (read-only) | `sonnet` | Turns the 3-way diff into a plan; never resolves a conflict silently. |
| `scripts/discover-targets.sh` | Shell | — | Picker: `plugins/*` that carry scaffold provenance. |
| `scripts/resolve-template-version.sh` | Shell | — | Materialize an **arbitrary** template version (ancestor / local / `--v`+`-v` tags) via `semver`. |
| `scripts/diff-components.sh` | Shell | — | 3-way classify (base/current/target), identity-rendered. |
| `scripts/apply-retarget.sh` | Shell | — | Apply approved decisions + provenance + CHANGELOG, inside the plugin dir only. |
| `scripts/plan-kit-path.sh` | Shell | — | Run-time locator for the shared `plan-kit` validator (`$PLAN_KIT_DIR` → marketplace ancestor → `PATH`); the plan-shape check itself is not vendored here. |

## Model selection

Both the command and the planner use `sonnet` — interpreting a diff and resolving
conflicts is moderate reasoning; `haiku` is too weak, `opus` more than needed. All version
math, resolution, diffing, and file mutation are deterministic shell (no model cost).

## Dependencies

- **`semver`** (plugin, `>=0.1.0`) — declared in `plugin.json`; `resolve-template-version.sh`
  reuses its engine (validate/compare) at run time (`$SEMVER_BIN` → marketplace ancestor →
  `PATH`), never vendored.
- **`plan-kit`** (plugin, `>=0.1.0`) — declared in `plugin.json`; the command resolves it
  via `scripts/plan-kit-path.sh` and runs its `validate-plan.sh --actions add,keep,update,delete`
  to gate the planner's JSON plan (whose actions use that vocabulary) before the confirm
  step. Shared, never vendored — the same plan-shape check every plan-confirm-apply plugin uses.
- **`jq`** (cli) — every script parses/writes JSON with it (guarded with `command -v`).
- **`git`** (cli) — `resolve-template-version.sh` lists and clones template release tags.

CLI tools have no `plugin.json` field; `dep-doctor` infers/verifies them.

## Challenging concepts & gotchas

- **Identity is sacred.** Apply re-renders `{{NAME}}`/`{{DESC}}` from the plugin's *own*
  `plugin.json`; it never rewrites the manifest's name/description or the plugin's docs. The
  3-way diff deliberately ignores `plugin.json`/`README.md`/`CONTEXT.md`/`CHANGELOG.md`.
- **Same template only.** It changes the *version* of the recorded template, never the
  template itself — switching templates means re-scaffolding.
- **No version bump.** It updates `scaffold.json.templateVersion` + the CHANGELOG
  `[Unreleased]` section but leaves `plugin.json`'s version alone; release-please bumps it
  from the resulting Conventional Commit (matching the repo's "never hand-edit released
  versions" rule).
- **Conflicts are the user's call.** The planner surfaces every `conflict` as a question;
  nothing silently overwrites a customization.
- **Downgrades are first-class.** A target below the current version is supported and uses
  the identical machinery.
- **Temp clones.** `resolve-template-version.sh` may clone a tag into a temp dir and returns
  its `cleanupPath`; the command `rm -rf`s it after applying.
