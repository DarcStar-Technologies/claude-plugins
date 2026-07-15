# plugin-forge — Context

> Design notes for humans and AI assistants. plugin-forge is the AI-assisted
> front-end to the deterministic `scripts/new-plugin.sh`: it decides *what* to
> build from a description and asks about anything unclear; the script does the
> mechanical file creation and registration.

## Purpose

Generate a new marketplace plugin from a natural-language description. Implements
[issue #2](https://github.com/DarcStar-Technologies/claude-plugins/issues/2).

## Mental model

Three layers, split along the repo's core principle — mechanize the
deterministic, use the minimum-capable model for the rest:

| Layer | Who | Responsibility |
| ----- | --- | -------------- |
| Understanding | `agents/plugin-planner.md` (sonnet) | Description → structured plan + clarifying questions. Read-only. |
| Orchestration | `commands/forge.md` | Runs the workflow: plan → ask → scaffold → realize → validate. |
| Mechanization | `scripts/new-plugin.sh`, `scripts/check-all.sh` (repo-level) | Create files, register in marketplace/release/provenance, validate. No model. |

plugin-forge deliberately owns **no** deterministic scaffolding logic of its own
— it calls the repo scripts so there is one source of truth.

## Workflow

1. `/forge <description>` establishes the repo root and reads the current
   `_template` version.
2. The `plugin-planner` agent turns the description into a JSON plan (name,
   components, per-component model + tools, keywords) and a list of questions.
3. `/forge` asks the user any clarifying questions and confirms the plan — it
   never guesses a requirement it can't infer.
4. It calls `scripts/new-plugin.sh <name>` to create and register the plugin.
5. It reconciles the copied `_template` examples with the plan (rewrite / keep /
   delete / add) and fills each component, setting the minimum-capable model.
6. It runs `scripts/check-all.sh` until the plugin is valid.

## Model selection

- `plugin-planner`: **sonnet** — mapping an open-ended description to a concrete,
  well-scoped plan (naming, choosing components, least-privilege tools) is genuine
  judgment: above bounded/mechanical work, short of deep architecture.
- `/forge` orchestration runs on the session model; its heavy lifting is delegated
  to shell rather than reasoned token-by-token.

## Challenging concepts & gotchas

- **Runs inside the marketplace repo.** plugin-forge authors plugins *for* this
  marketplace, so it expects a checkout where `scripts/new-plugin.sh` exists. It
  resolves the repo root with `git rev-parse --show-toplevel`.
- **Template *version* selection is limited.** Only the current template version is
  supported today. `_template` is excluded from release automation, so past
  versions aren't reachable via a tag; resolving an older version from the git
  history of `plugins/_template/` is a roadmap follow-up. When a user requests a
  specific version, `/forge` says so and proceeds with the current one only after
  they agree.
- **Provenance is inherited.** Because scaffolding goes through `new-plugin.sh`,
  every forged plugin gets `.claude-plugin/scaffold.json` recording the template
  and version, which `scripts/scaffold-report.sh` later uses for drift.
- **Ask, don't invent.** The planner emits `questions[]` for anything ambiguous;
  `/forge` must resolve them with the user before creating files.

## References

- Issue: <https://github.com/DarcStar-Technologies/claude-plugins/issues/2>
- Deterministic scaffolder: `../../scripts/new-plugin.sh`
- Repo conventions: `../../CONTRIBUTING.md`
