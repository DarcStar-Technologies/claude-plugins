# command-suite — Context

> Orientation for humans and AI assistants. This reference template exists to show
> how to structure a plugin whose value is a set of related slash commands.
> plugin-forge copies its component directories (not this file) when you scaffold
> `--template command-suite`; then rewrite the generated docs for the real plugin.

## Purpose

Demonstrate the **command-suite archetype**: several slash commands that each
delegate to one shared, deterministic script. It is a more specialized starting
point than `default` (a kitchen-sink example with a command, an agent, a skill,
and a script). Reach for `command-suite` when the plugin is essentially "a handful
of related commands" and needs no subagents or skills.

## Mental model

One script, many doors. `scripts/suite.sh` is the whole implementation; every
command is a thin wrapper that calls it with a different subcommand:

```text
/upper text  ->  scripts/suite.sh upper text
/count text  ->  scripts/suite.sh count text
```

Adding a command is a two-line change: a new `case` branch in `suite.sh` and a new
wrapper in `commands/`. Because the work lives in a script, it is deterministic,
testable, and spends **no** model tokens — the same "mechanize the deterministic
parts" principle the whole marketplace follows.

## How the pieces fit

```text
templates/command-suite/
├─ .claude-plugin/plugin.json   manifest: name, semver version, description
├─ commands/upper.md            /upper  ->  suite.sh upper
├─ commands/count.md            /count  ->  suite.sh count
├─ scripts/suite.sh             the deterministic backend (subcommand dispatcher)
├─ CONTEXT.md                   this file
├─ CHANGELOG.md                 Keep a Changelog + SemVer
└─ README.md                    user-facing overview
```

`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code to this plugin's directory, so each
command references the backend as `${CLAUDE_PLUGIN_ROOT}/scripts/suite.sh`
regardless of where the marketplace is installed.

## Model selection

There is deliberately **no model** in this template: the commands are pure
dispatch and the work is a shell script. When a real command-suite plugin does
need reasoning, add an agent/command with the **minimum capable model**
(`haiku` → `sonnet` → `opus`) and keep everything deterministic in `suite.sh`.

## Gotchas

- **Location, not naming:** templates live under `templates/`, so the validators
  treat this as internal — skipped for marketplace membership and never published,
  even though it is a fully valid plugin. (Nothing depends on a name prefix.)
- **Copies:** the scaffolder copies the component directories and substitutes the
  `{{NAME}}`/`{{DESC}}` placeholders; use those for anything that should become the
  new plugin's identity.
- **Versioning:** `command-suite` is release-managed like any plugin — tagged
  (`command-suite-v*`) for drift comparison and `--template-version` fetches, but
  kept out of the public catalog by its location. Its `README.md`/`CONTEXT.md`/
  `CHANGELOG.md` are in the release config's `exclude-paths`, so a commit that only
  touches its prose docs does **not** cut a new version — only changes to its
  components (commands/scripts) or manifest do.

## References

- Repository conventions and release flow: `../../CONTRIBUTING.md`
- The kitchen-sink template: `../default/`
- List available templates: `../../scripts/list-templates.sh`
