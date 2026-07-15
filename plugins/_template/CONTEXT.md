# _template — Context

> Orientation for humans and AI assistants. This reference plugin exists to show
> *how* a DarcStar plugin is structured and *why* it is structured that way.
> Copy it with `scripts/new-plugin.sh`, then rewrite this file for the real
> plugin.

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
_template/
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

## Model selection

| Task character                        | Model    | Example here        |
| ------------------------------------- | -------- | ------------------- |
| Deterministic / mechanical            | *(none)* | `scripts/example.sh` |
| Bounded reasoning / review            | `haiku`  | `example-reviewer`  |
| Moderate reasoning, editing           | `sonnet` | —                   |
| Deep architecture, ambiguous problems | `opus`   | —                   |

## Gotchas

- **Naming:** the `_` prefix marks this plugin as internal. The validation
  scripts skip `_`-prefixed plugins when checking marketplace membership, so it
  is never published even though it is fully valid.
- **Versioning:** release-please bumps `plugin.json` and writes the released
  `CHANGELOG.md` sections from Conventional Commits — don't hand-edit those, and
  keep `CHANGELOG.md` to an `[Unreleased]` section (the tool owns the versioned
  entries). `_template` is release-managed like any plugin — tagged, but kept out
  of the public catalog by its `_` prefix. Its version advancing (when you change
  template conventions) is what `scaffold-report.sh` compares against to flag
  drift in plugins built from an older template.
- **Changelog noise:** release-please attributes commits by path, so any commit
  touching `plugins/_template/**` (including broad foundation commits) lands in
  `_template`'s generated changelog. This is accepted — `_template` is internal —
  and release-please hides `ci`/`chore`/`docs`/`test` types by default, so only
  `feat`/`fix` subjects appear. Keep template edits in `_template`-scoped commits
  to keep it tidy.
- **Copies:** `new-plugin.sh` copies the component directories and rewrites the
  string `_template` to the new plugin name, so avoid using that literal string
  for anything you want preserved.
- **Provenance:** scaffolded plugins get `.claude-plugin/scaffold.json` naming
  the template and version they came from. `_template` itself has none — it is
  the source, not a scaffold. `../../scripts/scaffold-report.sh` surfaces which
  plugins were built from an older template version (`DRIFT`).

## References

- Repository conventions and release flow: `../../CONTRIBUTING.md`
- Validation scripts: `../../scripts/`
