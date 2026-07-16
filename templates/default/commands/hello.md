---
description: Greet the user via the plugin's mechanized shell script.
argument-hint: "[name]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/example.sh:*)
---

Run the plugin's deterministic greeting script and show its output.

1. Execute `${CLAUDE_PLUGIN_ROOT}/scripts/example.sh "$ARGUMENTS"`.
2. Report the greeting to the user verbatim.

This command is intentionally trivial. It exists to demonstrate the preferred
pattern: a command wires user input to a deterministic shell script rather than
asking the model to do work a script can do for free.
