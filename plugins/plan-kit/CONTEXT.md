# plan-kit — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Provide the **one canonical implementation** of the deterministic plan-shape check that
every [`plan-confirm-apply`](../../templates/plan-confirm-apply/) plugin needs — validate
the planner subagent's returned JSON plan before the command presents or acts on it — so
no plugin vendors its own copy of the check.

## Mental model

plan-kit is a **provider plugin**: no command, no agent, no skill — just `scripts/`. It is
the plan-flow analogue of [`edit-kit`](../edit-kit/) (the edit-flow toolkit) and
[`semver`](../semver/) (the versioning engine): a plugin that *owns* a deterministic tool
other plugins **resolve at run time** rather than copy.

The plan-confirm-apply archetype (a guided command → read-only planner subagent → confirm
→ apply) always has a planner that returns a JSON plan of the shape
`{summary, actions[], questions[]}`. Validating that shape is common functionality — the
same across every consumer — so it lives here, once.

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `scripts/validate-plan.sh` | Shell | Validate a JSON plan's shape (`summary` string, `actions[]` items each with a string `path` and an `action` in a caller-supplied vocabulary, `questions[]` array), naming the first violation. Reads a file arg or stdin. |

## Challenging concepts & gotchas

- **No command by design.** plan-kit is a library, not a user-facing plugin — it ships no
  `commands/`/`agents/`/`skills/`. Consumers own the model-driven flow (the command, the
  planner); plan-kit owns only the mechanical gate.
- **The action vocabulary is a parameter, not a constant.** Different consumers use
  different action verbs — the generic archetype uses `create`/`modify`/`delete`, but a
  retargeter uses `add`/`keep`/`update`/`delete`. `validate-plan.sh` takes `--actions
  a,b,c` (default `create,modify,delete`) so one script fits all consumers. Hardcoding a
  vocabulary here was the bug that made this worth extracting.
- **Only the shared shape is checked.** `summary` / `actions[]` / `questions[]` are common
  to every plan-confirm-apply plan; domain-specific extra fields (`risks[]`, per-action
  `detail`, a changelog category) are deliberately **tolerated**, never rejected — so a
  consumer can extend the plan shape without forking this script.
- **Resolved at run time, never vendored.** Consumers find the script via `$PLAN_KIT_DIR`
  → a marketplace ancestor's `plugins/plan-kit/scripts/` → `PATH` (the same pattern
  `edit-kit`, `semver`, and `scaffold-upgrade` use). A copy in a consumer would be drift
  waiting to happen — which is exactly why this exists.
- **`jq` is the one runtime dependency.** `validate-plan.sh` guards at start-up
  (`command -v jq || die`). Each action verb is bound to a variable *before* piping into
  the vocabulary array, so the array can't shadow the entry being tested.
- **Tests live at the repo root.** Per repo convention (and matching `edit-kit`),
  plan-kit's script tests are at `scripts/tests/plan-kit-*.bats` — run by CI's
  `bats scripts/tests` — not bundled in the plugin.
