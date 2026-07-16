# default — Context

> Orientation for humans and AI assistants. This reference template exists to show
> *how* a DarcStar plugin is structured and *why*. plugin-forge copies its
> component directories (not this file) when you scaffold `--template default`;
> then rewrite the generated docs for the real plugin.

## Purpose

Demonstrate the canonical plugin layout, the documentation contract every plugin
must satisfy, and the two design principles the marketplace enforces:

1. **Mechanize the deterministic parts.** Anything that does not require
   reasoning belongs in `scripts/` as a shell script — testable, fast, and
   free of model cost. The `/hello` command is deliberately trivial to make this
   point: it just runs `scripts/example.sh`.
2. **Use the minimum capable model.** Subagents and commands declare a `model:`
   in frontmatter. Pick the smallest model that produces correct results.
   `example-reviewer` uses `haiku` because its task is bounded.

## How the pieces fit

```text
templates/default/
├─ .claude-plugin/plugin.json   manifest: name, semver version, description
├─ commands/hello.md            /hello  ->  runs scripts/example.sh
├─ agents/example-reviewer.md   subagent, model: haiku, read-only tools
├─ skills/example-skill/SKILL.md model-invoked capability
├─ scripts/example.sh           deterministic greeting (no LLM)
├─ CONTEXT.md                   this file
├─ CHANGELOG.md                 Keep a Changelog + SemVer
└─ README.md                    user-facing overview
```

`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code to this plugin's directory, so
commands reference bundled files as `${CLAUDE_PLUGIN_ROOT}/scripts/example.sh`
regardless of where the marketplace is installed.

## Placeholders

Components may contain `{{NAME}}` and `{{DESC}}` — the scaffolder substitutes the
new plugin's name and description when it copies them (see `scripts/example.sh`,
whose greeting says `from the {{NAME}} plugin`). Anything without a placeholder is
copied verbatim. This replaced the old scheme of blind-rewriting the template's
own name, which the `_` prefix used to make safe.

## Model selection

| Task character                        | Model    | Example here        |
| ------------------------------------- | -------- | ------------------- |
| Deterministic / mechanical            | *(none)* | `scripts/example.sh` |
| Bounded reasoning / review            | `haiku`  | `example-reviewer`  |
| Moderate reasoning, editing           | `sonnet` | —                   |
| Deep architecture, ambiguous problems | `opus`   | —                   |

## Gotchas

- **Location, not naming:** templates live under `templates/` (a sibling of
  `plugins/`). The validators treat anything under `templates/` as internal — it
  is skipped for marketplace membership and never published, even though it is a
  fully valid plugin. (Nothing depends on a name prefix anymore.)
- **Versioning:** release-please bumps `plugin.json` and writes the released
  `CHANGELOG.md` sections from Conventional Commits — don't hand-edit those, and
  keep `CHANGELOG.md` to an `[Unreleased]` section (the tool owns the versioned
  entries). `default` is release-managed like any plugin — tagged (`default-v*`),
  but kept out of the public catalog by its location. Its version advancing (when
  you change template conventions) is what `scaffold-report.sh` compares against to
  flag drift in plugins built from an older template.
- **Changelog noise:** release-please attributes commits by path, so a commit
  touching `templates/default/**` lands in `default`'s generated changelog —
  *except* its prose docs (`README.md`/`CONTEXT.md`/`CHANGELOG.md`), which are in
  the release config's `exclude-paths`: a commit whose only `default` files are
  those docs does **not** bump it (so cross-cutting doc refreshes stop over-bumping
  the template). release-please also hides `ci`/`chore`/`docs`/`test` types by
  default, so only `feat`/`fix` subjects appear.
- **Copies:** the scaffolder copies the component directories and substitutes
  `{{NAME}}`/`{{DESC}}`; use those placeholders for anything that should become the
  new plugin's identity, and avoid them elsewhere.
- **Provenance:** scaffolded plugins get `.claude-plugin/scaffold.json` naming
  the template and version they came from. `default` itself has none — it is the
  source, not a scaffold. `../../scripts/scaffold-report.sh` surfaces which plugins
  were built from an older template version (`DRIFT`).

## References

- Repository conventions and release flow: `../../CONTRIBUTING.md`
- Validation scripts: `../../scripts/`
