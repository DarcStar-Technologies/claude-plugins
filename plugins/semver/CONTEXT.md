# semver — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Deterministic Semantic Versioning 2.0.0 operations — validate, compare, bump,
extract components, and compute the next version from Conventional Commits.
Implements [#10](https://github.com/DarcStar-Technologies/claude-plugins/issues/10).

## Mental model

Everything is a **pure, deterministic shell script** (`scripts/semver.sh`). The
`/semver` command is a thin wrapper that runs it and phrases the result. There is
**no model reasoning** in the answer — a textbook case of the repo's "mechanize
the deterministic / minimum-capable model" principle (the model here is
essentially *none*).

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `scripts/semver.sh` | Shell | The engine: validate / compare / bump / diff / next. |
| `commands/semver.md` | Slash command | `/semver <subcommand> …` — run the engine, report. |

## Engine reference

- `validate <v>` — exit 0 if valid semver, else non-zero.
- `compare <a> <b>` — `-1 | 0 | 1` (precedence of a vs b).
- `bump <major|minor|patch> <v>` — increment (resets lower components, drops
  pre-release/build).
- `major` / `minor` / `patch <v>` — the core component.
- `diff <a> <b>` — the highest-order difference: `major|minor|patch|prerelease|none`.
- `next <current> <git-range>` — the version implied by the Conventional Commits in
  the range (`feat`→minor, `fix`→patch, `!`/`BREAKING CHANGE`→major).

## Precedence (semver.org)

Numeric core compared numerically (`0.10.0` > `0.9.0`); a version without a
pre-release outranks one with; pre-release identifiers compared per spec (numeric
< alphanumeric, fewer identifiers < more); build metadata (`+…`) is ignored.

## Used by the repo itself

`../../scripts/scaffold-report.sh` reuses this engine (`compare`, `diff`,
`validate`) for template-drift detection instead of hand-rolling version math —
so the marketplace's own tooling depends on this plugin. Tests point at it via the
`SEMVER_BIN` env override so the drift gate stays isolated from the fixture.

## Gotchas

- `next` needs `git` and a valid range; everything else is pure string work.
- Keep it **dependency-free** (bash only) so it stays portable to any project.
