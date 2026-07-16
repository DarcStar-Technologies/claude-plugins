---
description: Count the words in the argument text via the plugin's shared suite script.
argument-hint: "[text]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/suite.sh:*)
---

Run the suite script's `count` subcommand and show its output.

1. Execute `${CLAUDE_PLUGIN_ROOT}/scripts/suite.sh count "$ARGUMENTS"`.
2. Report the word count to the user verbatim.

Part of the command suite backed by the single deterministic `scripts/suite.sh`;
adding a command means adding a subcommand there and a thin wrapper here.
