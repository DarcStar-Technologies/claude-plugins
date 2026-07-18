# plan-confirm-apply — Context

> Orientation for humans and AI assistants working on this template.

## Purpose

Reference template for the plan-confirm-apply archetype: a guided command that resolves a target, delegates to a read-only planner subagent for a structured change plan, requires explicit confirmation before touching disk, then applies and reverifies.

## Mental model

This is a **template**: an internal plugin under `templates/` whose component
directories (`commands/`, `agents/`, `skills/`, `scripts/`) the marketplace
scaffolder copies into new plugins, substituting `{{NAME}}`/`{{DESC}}`. It differs
from a published plugin only by living under `templates/` (never in
`marketplace.json`) — so keep the components archetype-shaped and generic.

## Dependencies

Declared in [`template.json`](./template.json) (the template manifest's cross-kind
`dependencies` list):

- **`jq`** (CLI tool) — `scripts/discover-targets.sh` parses `plugin.json` / marketplace
  metadata with it and guards at start-up (`command -v jq || die`). A plugin scaffolded
  from this template inherits that script, so it inherits the `jq` requirement.
- **`plan-kit`** (plugin) — the shared plan-shape validator. `guided-change.md` resolves
  it via `scripts/provider-path.sh` and runs its `validate-plan.sh` to gate the planner's
  JSON plan; the check is **not** vendored here. `forge-scaffold.sh` propagates this
  plugin-kind dependency into every scaffolded plugin's `plugin.json` `dependencies`, so
  Claude Code auto-installs `plan-kit` alongside the consumer.

## Challenging concepts & gotchas

- **The confirm-before-edit gate is the whole point.** The command must present the
  planner's plan and get an explicit go-ahead **before** any Edit/Write. Preserve that
  ordering (plan → confirm → apply) when adapting the command; a `--dry-run` path stops
  right after the preview.
- **The plan is validated before it's ever shown — by the shared `plan-kit` provider.**
  `guided-change.md` step 3 resolves plan-kit (`scripts/provider-path.sh`) and runs its
  `validate-plan.sh` on the planner's JSON — before step 4 (unknowns) or step 5 (confirm)
  ever runs — retrying at most 3 times, sending a malformed or ill-shaped plan back to the
  planner instead of presenting or acting on it. A plan the planner regenerates in step 4
  is re-validated, not trusted from step 3; and under `--dry-run` validation is advisory
  (an unresolvable plan-kit or a failing plan still shows the preview). The check is
  **not** vendored here (it
  used to be; it was extracted so a fix propagates to every consumer). It checks only the
  archetype-shared shape (`summary` / `actions[]` / `questions[]`) against a `--actions`
  vocabulary that defaults to `create,modify,delete`; a consumer whose planner uses a
  different verb set passes `--actions <its,verbs>` rather than forking the script.
- **The planner is read-only.** `agents/planner.md` (`name: {{NAME}}-planner`) plans and
  asks clarifying questions — it never writes files. Keep its tool list read-only.
- **`discover-targets.sh` is domain-parameterized.** It ships with generic
  `ROOT_MARKER` / `CANDIDATES_DIR` / `DESCRIPTOR` env defaults; a scaffolded plugin
  points them at its own layout. It exits non-zero (no output) when there's no root
  marker so the command falls back to a free-text prompt, and prints `[]` when the root
  has no candidates — keep those two signals distinct.
- **Placeholders.** Components use `{{NAME}}`/`{{DESC}}` for the scaffolded plugin's
  identity (e.g. the agent name `{{NAME}}-planner`, the command's `description`). The
  forge scaffolder substitutes them on copy.
- **This is deliberately domain-neutral.** It was distilled from a plugin-editing
  plugin, but the changelog/versioning/template-drift housekeeping was dropped — that
  is a consumer's concern, not the archetype's. Add your own post-apply steps in the
  command's apply/verify phase.
