---
description: Report whether a scaffolded plugin can be upgraded to the latest version of its source template.
argument-hint: "[plugin-dir]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-upgrade.sh:*)
---

Report whether a plugin created from a template is behind the latest version of
that template. **Read-only** — it never modifies the plugin.

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/check-upgrade.sh "$ARGUMENTS"` (the plugin
   directory defaults to `.` when `$ARGUMENTS` is empty).
2. Report the script's output verbatim. When an upgrade is available the script
   already prints the semver gap and what changed in the template — relay it as-is;
   do not re-derive or embellish it.

This command is deterministic. The script reads the plugin's
`.claude-plugin/scaffold.json` provenance, resolves the latest template version
(from an ancestor marketplace, a local path, or the template's `<name>-v*` release
tags), and compares them by reusing the `semver` engine — no model reasoning is
spent on it.
