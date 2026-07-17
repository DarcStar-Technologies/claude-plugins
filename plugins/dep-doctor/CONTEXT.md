# dep-doctor — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Tell a user whether a plugin's **dependencies** — CLI tools, libraries, MCP servers, and
other plugins — are present and correctly configured, and (only with confirmation) install
the ones that aren't. It answers "will this plugin actually work in my environment?"

## Mental model

A **plan → confirm → apply** flow where the split between read and write is the whole
point: **checking is read-only; installing is a confirmed mutation, tightly constrained.**

```text
/dep-doctor [--check-only] [--dry-run] [<plugin-dir>]
   │
   ├─ resolve target plugin              → picker via discover-plugins.sh
   ├─ dep-planner (agent, read-only)     → infer deps → check-deps.sh → plan remediation
   ├─ report inventory (OK/MISSING/WRONG-VERSION/UNKNOWN)
   │     └─ --check-only? stop here (nothing is installed)
   ├─ confirm with the user              → NOTHING is installed before this
   │     └─ --dry-run? show the exact install commands and STOP
   ├─ apply-remediation.sh (auto actions only) + print manual steps
   └─ re-verify (check-deps.sh again)
```

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `commands/dep-doctor.md` | Slash command (`sonnet`) | Orchestrates the flow; gates installing behind confirmation. |
| `agents/dep-planner.md` | Subagent (`sonnet`, read-only) | Infers deps, runs `check-deps.sh`, plans remediation (auto vs manual). |
| `scripts/discover-plugins.sh` | Shell | Discover the marketplace's plugins for the picker (absolute paths). |
| `scripts/check-deps.sh` | Shell | Deterministic, **read-only** checker: classifies each dep OK/MISSING/WRONG-VERSION/UNKNOWN. |
| `scripts/apply-remediation.sh` | Shell | The **only** mutating step — an allow-listed, confirmation-gated installer. |

## Dependency kinds & how they are checked

- **cli** — `command -v <name>`; an optional **allow-listed** `versionFlag` (default
  `--version`) + `versionPattern` (ERE) distinguishes OK from WRONG-VERSION. The flag is
  never a free-form argument array, so a descriptor can't smuggle arbitrary arguments into
  the probed command.
- **library** — a bounded interpreter probe (`python -c "import <module>"`,
  `node -e "require('<module>')"`, `ruby -e "require '<module>'"`); the module name must be
  a plain identifier or it is not probed.
- **mcp** — presence in `claude mcp list` when the `claude` CLI is available, else UNKNOWN.
- **plugin** — a record in `installed_plugins.json` (the same lookup plugin-editor's
  `check-install-status.sh` uses; path overridable via `$INSTALLED_PLUGINS_JSON`).

## Challenging concepts & gotchas

- **Read/write split is the safety property.** `check-deps.sh` never mutates. Only
  `apply-remediation.sh` installs, and only after explicit user approval.
- **No arbitrary command execution.** `apply-remediation.sh` takes **structured**
  `{installer, package}` actions, not command strings; it constructs the command itself
  from an allow-list (`npm`/`pip`/`pip3`/`pipx`/`cargo`/`go`) and validates the package is a
  plain token. `sudo`, system package managers, plugin installs, and MCP setup are
  **refused** and surfaced as manual steps. Interpreter probes in `check-deps.sh` likewise
  reject non-identifier module names so a descriptor can't smuggle code.
- **It never edits the target plugin.** dep-doctor inspects a plugin and installs *its
  dependencies into the environment* — it does not modify the plugin's files (that's
  `/edit-plugin`'s job).
- **Dependencies are inferred, not declared.** There is no required manifest field, so the
  planner infers deps from the plugin's own files; an author can add an explicit
  `.claude-plugin/dependencies.json`, whose entries win over inference.
- **`UNKNOWN` is honest, not a failure.** When a check can't be made deterministically
  (no runtime for a library, no `claude` CLI for an MCP), the status is UNKNOWN with a note
  to verify manually — it never guesses OK.

## Model selection

Both the command and the planner use `sonnet` — inferring dependencies from prose/scripts
and planning safe remediation is moderate reasoning; `haiku` is too weak. All checking and
installing is deterministic shell at **no** model cost.
