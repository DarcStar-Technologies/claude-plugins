---
description: Diagnose a target plugin's dependencies — CLI tools, libraries, MCP servers, and other plugins — and, with explicit confirmation, install or fix what is missing via a plan-confirm-apply flow.
argument-hint: "[--check-only] [--dry-run] [<plugin-dir>]"
allowed-tools: Bash, Read, Glob, Grep, Task, AskUserQuestion
model: sonnet
---

Check whether a target plugin's dependencies are installed correctly and — with your
explicit approval — install what's missing. This is the plan → confirm → apply archetype:
**verification is read-only; installing is a mutation that never happens without a
go-ahead.** Work through the steps in order.

`$ARGUMENTS` is an optional target plugin directory plus the flags `--check-only` (verify
and report only — never propose or apply remediation) and `--dry-run` (show the
remediation plan and the exact install commands, but apply nothing).

## 1. Resolve the target plugin

Each Bash call is a **fresh shell**, so recompute paths every time. Parse the leading
flags (`--check-only`, `--dry-run`), then resolve the target:

- an explicit `<plugin-dir>` argument; else the current directory if it has
  `.claude-plugin/plugin.json`; else offer a **picker** — run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/discover-plugins.sh"`; if it prints a non-empty JSON
  array, choose with `AskUserQuestion` (≤4 options — label = `name`, description =
  `description`; use the entry's absolute `path`; the built-in "Other" is added for you).
  If it exits 2 or returns `[]`, fall back to asking for a path.
- Confirm the resolved directory is a plugin (`.claude-plugin/plugin.json` exists). If
  not, stop and say so.

## 2. Plan (delegate to the planner)

Invoke the `dep-planner` agent (Task tool) with the target plugin directory. It reads the
plugin's declared `dependencies` (the first-class `plugin.json` field) as authoritative
plugin deps and infers the rest (CLI/library/MCP) from its docs and scripts (plus a legacy
`.claude-plugin/dependencies.json` if present), runs the read-only `check-deps.sh` to
classify each,
and returns a JSON plan: `summary`, `dependencies[]` (each `kind`, `name`, `status` of
OK/MISSING/WRONG-VERSION/UNKNOWN, `detail`), `remediation[]` (each targets a non-OK
dependency and is either **auto** — an allow-listed `installer` + `package` — or
**manual** — with a `manualCommand` and why it can't be auto-applied), `risks[]`, and
`questions[]`. If it doesn't return one valid JSON object, ask it to try again.

## 3. Resolve unknowns — ask, don't guess

If the plan has `questions`, ask them (`AskUserQuestion` for discrete choices) and re-run
the planner if the answers change the plan.

## 4. Report — always show the inventory

Present the dependency inventory grouped by status (OK / MISSING / WRONG-VERSION /
UNKNOWN) with each `detail`, then the proposed remediation (which actions are auto vs
manual) and any `risks`.

- **If `--check-only`:** stop here — this is a read-only report; propose and apply
  nothing.
- **If every dependency is OK:** say so and stop; there is nothing to remediate.

## 5. Preview / confirm — do NOT install yet

- **If `--dry-run`:** run `"${CLAUDE_PLUGIN_ROOT}/scripts/apply-remediation.sh" --dry-run`
  with the plan's **auto** actions to show the exact commands, print the **manual** steps
  too, state that **nothing was installed**, give the command to re-run without
  `--dry-run`, and **STOP**.
- **Otherwise:** get an explicit go-ahead before installing. The user may approve a
  subset — apply only what they approve.

## 6. Apply — the only mutating step

- Pass the approved **auto** actions (each `{installer, package}`) to
  `"${CLAUDE_PLUGIN_ROOT}/scripts/apply-remediation.sh"` and relay its output. It runs
  only allow-listed, user-scoped installers (`npm`/`pip`/`pip3`/`pipx`/`cargo`/`go`) and
  **refuses** anything else (`sudo`, system package managers, plugin/MCP installs) — those
  come back as REFUSED and must be done by the user.
- **Print the manual steps** (plugin installs like `/plugin install <name>`, MCP server
  setup, anything refused) with their exact commands for the user to run themselves.
- This step only touches the **environment** (installed tools/plugins) — never the target
  plugin's own files.

## 7. Re-verify

Re-run the planner's check (or `check-deps.sh` on the same dependency set) and report
which dependencies are now OK and which still need manual action.

## 8. Summary

Summarize: what was checked, what was installed (and by which installer), what still needs
manual steps (with commands), and the final OK/not-OK status per dependency.

Throughout: verification is read-only; **never install without explicit approval**; keep
deterministic work in the scripts; and only ever run the allow-listed installers — surface
everything else as a manual step.
