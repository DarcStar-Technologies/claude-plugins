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
  metadata with it, and `scripts/validate-plan.sh` uses it to validate the planner's JSON
  plan shape; both guard at start-up (`command -v jq || die`). A plugin scaffolded from
  this template inherits both scripts, so it inherits the `jq` requirement.

The template needs no *plugin* dependencies — its components resolve nothing from a sibling
plugin (unlike `plugin-editor`, whose edit-kit coupling was deliberately dropped here).

## Challenging concepts & gotchas

- **The confirm-before-edit gate is the whole point.** The command must present the
  planner's plan and get an explicit go-ahead **before** any Edit/Write. Preserve that
  ordering (plan → confirm → apply) when adapting the command; a `--dry-run` path stops
  right after the preview.
- **The plan is validated before it's ever shown.** `scripts/validate-plan.sh` gates the
  planner's JSON output in step 3 of `guided-change.md` — before step 4 (unknowns) or
  step 5 (confirm) ever runs — and retries at most 3 times, sending a malformed or
  ill-shaped plan back to the planner instead of presenting or acting on it. It checks
  only the archetype-shared shape (`summary` / `actions[]` / `questions[]`), so it needs
  no adaptation after scaffolding.
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
