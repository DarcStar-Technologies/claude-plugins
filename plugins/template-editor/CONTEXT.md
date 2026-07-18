# template-editor — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Make modifying an existing **reference template** safe and routine — the template
analogue of `plugin-editor`. A change request against a template under `templates/` is
turned into a reviewed plan, applied inside that template only, and run through the
housekeeping every edit needs (structure check, changelog, version guidance, repo
verification).

## Mental model

**The model does the irreducible reasoning; deterministic work is shared scripts.**
Interpreting a request and editing components needs a model. The mechanical steps —
changelog insertion, version guidance, structural validation, post-edit verification,
test-stub scaffolding — are **not** this plugin's own: they are reused from the
[`edit-kit`](../edit-kit/) provider plugin, resolved at run time. template-editor owns
only what is *template-specific*.

```text
/edit-template [--dry-run] [--template=<dir>] [--type=…] [<dir>] [— <change>]
   │
   ├─ not in a marketplace repo?         → stop (templates only live there)
   ├─ resolve target template            → picker via discover-templates.sh; MUST be
   │                                        under templates/ (never plugins/)
   ├─ guided intake (change-type + suggestions grounded in the template)
   ├─ template-edit-planner (agent, read-only) → a concrete plan + questions
   ├─ validate plan shape → plan-kit's validate-plan.sh --field files (via plan-kit-path.sh)
   ├─ confirm with the user              → NOTHING is edited before this
   ├─ apply (only inside templates/<name>/, preserving {{NAME}}/{{DESC}})
   ├─ verify the edits landed
   └─ housekeeping via edit-kit          → EK="$(edit-kit-path.sh <dir>)"; then
        check-structure.sh · update-changelog.sh · sync-version.sh ·
        scaffold-test.sh (new scripts) · verify-repo.sh
```

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `commands/edit-template.md` | Slash command (`sonnet`) | Orchestrates the flow; applies edits; resolves and runs the edit-kit scripts. |
| `agents/template-edit-planner.md` | Subagent (`sonnet`, read-only) | Interprets the request; returns the edit plan; preserves placeholders. |
| `scripts/discover-templates.sh` | Shell | Discover the marketplace's templates for the picker (wraps `list-templates.sh --json`, absolute paths). |
| `scripts/edit-kit-path.sh` | Shell | Resolve the `edit-kit` scripts dir at run time (`$EDIT_KIT_DIR` → marketplace ancestor → `PATH`). |
| `scripts/plan-kit-path.sh` | Shell | Resolve the `plan-kit` scripts dir at run time (`$PLAN_KIT_DIR` → marketplace ancestor → `PATH`) for the shared plan-shape validator. |

The edit-flow scripts (`check-structure.sh`, `update-changelog.sh`, `sync-version.sh`,
`scaffold-test.sh`, `verify-repo.sh`) live in **`edit-kit`**, not here; the plan-shape
validator (`validate-plan.sh`) lives in **`plan-kit`**.

## Model selection

Both the command and the planner use `sonnet` — interpreting an edit request and
editing template components is moderate reasoning; `haiku` is too weak, `opus` more than
needed. All mechanical work is in shell scripts (this plugin's two, plus edit-kit's) at
**no** model cost.

## Challenging concepts & gotchas

- **Templates only, never plugins.** The command resolves a target **under `templates/`**
  and refuses anything else — editing a published plugin is `/edit-plugin`'s job. That
  guard is the plugin's key scoping property.
- **Preserve `{{NAME}}`/`{{DESC}}`.** A template's components carry those placeholders as
  the identity a future scaffolded plugin inherits. Edits keep them; the planner flags a
  hard-coded-identity leak in `risks[]`. Never substitute a concrete name into a
  component.
- **edit-kit is resolved, not vendored.** `edit-kit-path.sh` finds edit-kit's scripts
  (`$EDIT_KIT_DIR` → marketplace ancestor → `PATH`); if edit-kit isn't installed the
  command says so. This is the same run-time-reuse pattern `sync-version.sh` uses for
  `semver`. A copy here would be drift waiting to happen. edit-kit is also a versioned
  **`dependencies` entry in `plugin.json`** (`edit-kit >=0.1.0`) so Claude Code auto-installs
  it (and transitively `semver`) when template-editor is installed, resolving the range
  against the marketplace's `edit-kit--v*` tags — and disables template-editor if it can't;
  `edit-kit-path.sh` then just *locates* the installed toolkit at run time (and finds the
  sibling `plugins/edit-kit` in the repo checkout).
- **plan-kit gates the plan.** Step 3 resolves plan-kit (`plan-kit-path.sh`) and runs its
  `validate-plan.sh --field files --actions create,modify,delete` on the planner's JSON
  before the confirm gate. This planner's change array is `files[]` (not the archetype's
  `actions[]`), which the shared validator's `--field` option accommodates — one validator,
  no fork. plan-kit is a versioned `dependencies` entry (`plan-kit >=0.2.0`, the release
  that added `--field`), auto-installed like edit-kit; under `--dry-run` validation is
  **advisory** — an unresolvable plan-kit or a plan that fails validation still shows the
  preview (a dry run mutates nothing), while a real apply hard-gates on it. A plan
  regenerated in step 4 is re-validated, not trusted from step 3.
- **No install/reload step.** Unlike `plugin-editor`, there is no `check-install-status`
  — a template is a scaffolding *source*, never installed.
- **No template drift.** `check-structure.sh` (edit-kit) validates structure only; a
  template has no `scaffold.json` upstream to drift from — it *is* the archetype.
- **Versioning is context-aware.** Templates are release-please-managed (`<name>-v*`
  tags), so `sync-version.sh` prints the Conventional Commit to land — do **not**
  hand-bump `plugin.json`.
