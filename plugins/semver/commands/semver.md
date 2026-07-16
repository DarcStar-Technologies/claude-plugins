---
description: Semantic-versioning operations — validate, compare, bump, or compute the next version.
argument-hint: "<validate|compare|bump|major|minor|patch|diff|next> ..."
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/semver.sh:*)
---

Run the deterministic semver helper with the user's arguments and report the result.

`$ARGUMENTS` holds the subcommand and its operands, e.g. `compare 1.2.0 1.10.0`.

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/semver.sh $ARGUMENTS`.
2. Report the output plainly, translating where it helps:
   - `compare` prints `-1 | 0 | 1` → say "<first> is older", "equal", or "<first>
     is newer".
   - `validate` → state whether the version is valid (and the exit code).
   - `next` → show the computed next version.
3. If no arguments are given, run the script with no arguments to show its usage,
   rather than guessing what the user meant.

The answer is computed by a deterministic shell script — no model reasoning is
needed to produce it, only to phrase it.
