---
description: {{DESC}}
argument-hint: "[--dry-run] [<target>] [— <what to change>]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
model: sonnet
---

Apply a change to a target safely. This is the **plan → confirm → apply** archetype:
work through the steps in order and **never edit anything until the user approves the
plan.**

`$ARGUMENTS` is an optional target followed by an optional free-text change
description — both optional, since guided intake (step 2) can supply what's missing.
The flag `--dry-run` may appear before the change description.

## 1. Resolve the target

- **Split off the change description first, then parse flags.** Everything after a
  `—` change-description separator is the **literal change description** — never scan
  it for flags. What precedes it is the **directive segment**: an optional `--dry-run`
  flag plus an optional `<target>`. With no separator, recognize `--dry-run` only as a
  **leading** token (before `<target>`) so a `--dry-run` inside the change text stays
  literal.
- **`--dry-run`** → preview the plan and stop, never touching disk (see step 5).
- **Resolve the target:** if the directive segment names one, use it. Otherwise offer a
  **picker** instead of guessing: run `"${CLAUDE_PLUGIN_ROOT}/scripts/discover-targets.sh"`
  (recompute the path in each fresh shell). If it prints a non-empty JSON array, use
  `AskUserQuestion` to let the user choose — one option per entry (label = `name`,
  description = `description`; use the chosen entry's `path`, which is absolute). Since
  `AskUserQuestion` allows at most **4** options, when there are more entries present
  the 4 most relevant and rely on its built-in **"Other"** for the user to name another
  (or ask them to narrow first). Only if the script exits non-zero or returns `[]` fall
  back to asking in free text.
- Confirm the resolved target exists before continuing; if not, stop and say so.

## 2. Guided intake — fill in what's missing

Judge whether the change description is **already fully specified** (real, actionable
text, not empty or a placeholder):

- **If it is:** skip to step 3.
- **If it is not:** gather what's missing with `AskUserQuestion` — never re-asking
  anything the invocation already answered. Ask the kind/scope of change, then offer
  3–5 concrete, target-specific suggestions (always keeping the built-in **"Other"**
  free-form option). Fold the answers into one concrete change description.

## 3. Plan (delegate to the planner)

- Invoke the `{{NAME}}-planner` agent (Task tool) with the target and the requested
  change. It returns a JSON plan (`summary`, `actions[]`, `risks[]`, `questions[]`). If
  it does not return one valid JSON object, ask it to try again.

## 4. Resolve unknowns — ask, don't guess

- If the plan has `questions`, ask them (`AskUserQuestion` for discrete choices) and
  re-run the planner with the answers if they change the plan.

## 5. Confirm the plan — do NOT edit yet

- Present the plan: the files it will touch and how, plus any `risks`.
- **If this is a `--dry-run`:** label the plan a **DRY RUN / PREVIEW**, state
  explicitly that **nothing on disk was or will be changed**, and give the exact
  command to re-run **without** `--dry-run`. Then **STOP** — do not proceed to step 6
  (apply), step 7 (verify), or step 8 (summary).
- **Otherwise:** get an explicit go-ahead before making any change, then continue.

## 6. Apply the edits

- Make exactly the actions in the approved plan, operating **only inside the resolved
  target**. Each action's `path` is **relative to the resolved target** — join it to the
  target directory (never apply it against your current working directory). Use
  Edit/Write. Never touch anything outside the target. Push anything fully deterministic
  into a `scripts/*.sh` step rather than doing it by hand.

## 7. Verify the edits landed

- Re-read **every** file in the plan's `actions[]` (each `path` resolved against the
  target directory, as in step 6) and confirm the specific change is actually present —
  a semantic check, not just that the file parses. For a deletion, confirm the file or
  capability is really gone.
- If a change didn't land or landed wrong, fix it with Edit and re-check. If you can't
  resolve it, stop and tell the user exactly what is missing before going on.

## 8. Summary

Give the user a clear summary: each file touched and, in one line, what changed (as
confirmed in step 7); any residual risks to review; and the next step.

Throughout: ask when unsure, keep deterministic work in `scripts/`, prefer the
minimum-capable model for any new component, and never edit outside the resolved
target.
