---
description: Uppercase the argument text via the plugin's shared suite script.
argument-hint: "[text]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/suite.sh:*)
---

Run the suite script's `upper` subcommand and show its output.

1. Execute `${CLAUDE_PLUGIN_ROOT}/scripts/suite.sh upper "$ARGUMENTS"`.
2. Report the result to the user verbatim.

This command is one of several thin wrappers that share a single deterministic
script (`scripts/suite.sh`) — the *command-suite* pattern: many entry points, one
mechanized backend, zero model cost.
