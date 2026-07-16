# plan-confirm-apply

Reference template for the plan-confirm-apply archetype: a guided command that resolves a target, delegates to a read-only planner subagent for a structured change plan, requires explicit confirmation before touching disk, then applies and reverifies.

Not published to the public catalog — this is a reference **template** the
marketplace scaffolder copies component directories from.

## Components

This template models the **plan → confirm → apply** archetype — a guided command
backed by a read-only planner subagent and a deterministic discovery script:

| Path | Role |
| ---- | ---- |
| `commands/guided-change.md` | The orchestrator: resolve a target (picker via the script), run guided intake, delegate to the planner, **confirm before any edit**, apply, then re-verify. Supports a `--dry-run` preview. |
| `agents/{{NAME}}-planner` (`agents/planner.md`) | Read-only subagent that returns a structured JSON plan (`summary` / `actions[]` / `risks[]` / `questions[]`) for the command to present — it plans, it never edits. |
| `scripts/discover-targets.sh` | Deterministic discovery: root marker → candidate dirs → `{name, path, description}` JSON for the picker. |

Components use `{{NAME}}`/`{{DESC}}` placeholders for anything that should become the
scaffolded plugin's identity. The archetype's value is the **confirm-before-edit
gate**: nothing touches disk until the user approves the plan.

To adapt after scaffolding: point `discover-targets.sh` at your domain (its
`ROOT_MARKER` / `CANDIDATES_DIR` / `DESCRIPTOR`), and extend the planner's plan shape
with any fields your domain needs.
