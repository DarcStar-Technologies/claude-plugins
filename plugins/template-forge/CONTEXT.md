# template-forge — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Make creating a new **reference template** routine and correct. A template is an
internal plugin under `templates/` whose component dirs the marketplace scaffolder
(`forge-scaffold.sh`) copies into new plugins, substituting `{{NAME}}`/`{{DESC}}`.
Adding one by hand means getting three things right at once — a valid plugin under
`templates/`, the release-please registration, and *not* adding it to the catalog —
so this plugin mechanizes that.

## Mental model

**The model does the irreducible reasoning; the script does everything
deterministic.** Interpreting what archetype the user wants, and authoring or
genericizing components, needs a model. Creating `templates/<name>/`, reversing a
source plugin's identity back to placeholders, and editing the release config /
manifest are deterministic — a tested shell script. The command is the conductor:

```text
/forge-template [--from-plugin <dir>] [<name>] [— <what it's for>]
   │
   ├─ not in a marketplace repo?        → stop (templates only exist in one)
   ├─ pick the input path:
   │    ├─ --from-plugin <dir>          → reverse-engineer a plugin (picker if none)
   │    ├─ a real description           → plan from it
   │    └─ thin/absent                  → guided intake (AskUserQuestion)
   ├─ template-planner (agent, read-only) → a concrete plan + questions
   ├─ confirm with the user             → NOTHING is created before this
   ├─ template-forge-scaffold.sh        → templates/<name>/ + release registration
   ├─ realize (only inside templates/<name>/) → author / reconcile components
   └─ check-all.sh + npm test
```

The **plan → confirm → create** ordering is the core safety property.

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `commands/forge-template.md` | Slash command (`sonnet`) | Orchestrates the flow; picks the input path; runs the scaffolder; reconciles components. |
| `agents/template-planner.md` | Subagent (`sonnet`, read-only) | Interprets the request (or reads a source plugin) and returns the plan. |
| `scripts/template-forge-scaffold.sh` | Shell | Creates `templates/<name>/`, does the reverse name→placeholder copy for `--from-plugin`, and registers the template (release config + manifest). |

## Model selection

Both the command and the planner use `sonnet` — interpreting an archetype request
and genericizing components is moderate reasoning; `haiku` is too weak for reliable
authoring and `opus` more than it needs. All mechanical work lives in `scripts/` at
**no** model cost.

## Challenging concepts & gotchas

- **A template is defined by its location, not a name prefix.** Living under
  `templates/` (a sibling of `plugins/`) is what makes a plugin internal —
  validators skip it for marketplace membership. So the scaffolder registers a new
  template in `release-please-config.json` and `.release-please-manifest.json` but
  **never** in `marketplace.json`. Adding a marketplace entry would publish it.
- **Templates carry no `scaffold.json`.** They are the *source* of scaffolding, not
  scaffolded from anything — `validate-manifests.sh` requires provenance only for
  public plugins under `plugins/`.
- **First release is `0.1.0`.** The manifest is seeded at `0.0.0`; the repo's
  release-please `initial-version` (0.1.0) makes the first `<name>-v*` release a clean
  0.1.0. Do not hand-edit template versions.
- **Only components carry placeholders.** The template's own docs and `plugin.json`
  use its real name; only the component files use `{{NAME}}`/`{{DESC}}` (what a future
  plugin inherits). A template's prose docs are in the release config's `exclude-paths`
  so doc-only edits don't cut a new template version.
- **`--from-plugin` reverse substitution is best-effort and textual.** It replaces the
  source plugin's *description first* then its *name* (the name often occurs inside the
  description, so name-first would corrupt the longer match), across every non-binary
  copied file. It cannot understand semantics — the command/model reconciles anything
  plugin-specific it can't safely genericize.
- **Idempotent, fail-fast.** The scaffolder dies if `templates/<name>/` exists or the
  release package is already registered — and it checks the package **before** writing
  any files, so a re-run can't half-create a template.
- **Deterministic dependency.** `jq` is required (registration is jq edits).
