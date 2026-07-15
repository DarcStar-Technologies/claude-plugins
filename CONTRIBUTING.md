# Contributing

Thanks for contributing to the DarcStar Technologies plugin marketplace. This
repository is automated end to end: if you follow the conventions below, tooling
handles versioning, changelogs, and validation for you.

## Prerequisites

- **Node.js** ≥ 18 (for commitlint and markdownlint)
- **jq** (manifest tooling)
- **pre-commit**, **shellcheck**, **bats** (local checks; CI installs its own)

Set up once per clone:

```bash
npm install
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
```

## Adding a plugin

```bash
scripts/new-plugin.sh my-plugin --description "What it does"
scripts/check-all.sh
```

`new-plugin.sh` creates `plugins/my-plugin/` from `templates/` and the
`_template` reference, then registers the plugin in `marketplace.json`,
`release-please-config.json`, and `.release-please-manifest.json`. Every plugin
must keep its `CONTEXT.md`, `CHANGELOG.md`, `README.md`, and a valid
`.claude-plugin/plugin.json`.

Pass `--template <name>` to scaffold from a different internal template (default
`_template`). The command records provenance in
`plugins/<name>/.claude-plugin/scaffold.json` — the template name and the
template version the plugin was generated from. **CI requires this file on every
public plugin.** Review provenance and spot templates that have moved on since a
plugin was created with:

```bash
scripts/scaffold-report.sh   # PLUGIN / TEMPLATE / SCAFFOLD / CURRENT / STATUS
```

Statuses:

- `DRIFT` — a newer **minor/patch** template exists. Informational; never fails.
- `MAJOR-DRIFT` — the template advanced a **major** version. **CI fails on this**
  (`scripts/scaffold-report.sh --strict`, also `npm run scaffold:check`) unless
  the plugin is on the exception list.
- `MAJOR-DRIFT(allowed)` — major drift, but the plugin is on the exception list.

### Major-drift exception list

To consciously accept that a plugin lags a major template version, add it to
`.scaffold-exceptions.json` at the repo root — a map of `plugin-name → reason`:

```json
{
  "exceptions": {
    "legacy-plugin": "Pinned to template v1 until the Q4 migration"
  }
}
```

The reason is required (it is the audit trail). Remove the entry once the plugin
is migrated; the report warns about exceptions naming plugins that don't exist.

## Commit messages — Conventional Commits

Commit messages are linted (commitlint) and drive releases, so they matter.

```text
<type>(<scope>): <subject>
```

- **type**: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`,
  `chore`, `revert`
- **scope**: the plugin name (e.g. `my-plugin`) or a repo area (`scripts`, `ci`,
  `release`, `docs`)
- Append `!` (or a `BREAKING CHANGE:` footer) for a major bump.

```text
feat(my-plugin): add /summarize command
fix(scripts): handle plugins with no components
feat(my-plugin)!: rename the primary command
```

Bump mapping: `fix` → patch, `feat` → minor, `!`/`BREAKING CHANGE` → major.

## Versioning & changelogs — do not do this by hand

Each plugin is versioned independently with [SemVer](https://semver.org/), and
each has its own `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com/)
format. **release-please** reads merged Conventional Commits on `main`, opens a
release PR that bumps the affected `plugin.json` versions and writes their
changelog entries, and tags releases when that PR merges.

You therefore **never** manually edit released version numbers or generated
changelog sections. The repo-level [`CHANGELOG.md`](./CHANGELOG.md) tracks
tooling/structure changes and is curated by maintainers.

> **Maintainers — release token.** This org's enterprise policy blocks the
> default `GITHUB_TOKEN` from opening pull requests, so `release.yml` runs
> release-please with a fine-grained PAT stored as the `RELEASE_PLEASE_TOKEN`
> secret (Contents: RW, Pull requests: RW, scoped to this repo). Until that
> secret exists the release job skips cleanly. Rotate the token before it
> expires.

## Model selection

Use the **minimum capable model** for every subagent and command (`model:`
frontmatter):

| Task character                        | Model    |
| ------------------------------------- | -------- |
| Deterministic / mechanical            | *(script, no model)* |
| Bounded reasoning / review            | `haiku`  |
| Moderate reasoning, editing           | `sonnet` |
| Deep architecture, ambiguous problems | `opus`   |

Push anything fully deterministic into a `scripts/` shell script with a `bats`
test rather than spending model tokens on it.

## Local checks

```bash
pre-commit run --all-files   # everything the hooks enforce
scripts/check-all.sh         # manifests, docs, versions
npm test                     # bats tests for the shell scripts
scripts/lint.sh              # shellcheck / shfmt / markdownlint / actionlint
```

## What CI enforces (merge gates)

- **Manifest & schema validation** — `marketplace.json` and every `plugin.json`.
- **Semver + changelog structure** — valid versions, Keep a Changelog format.
- **Docs present** — `CONTEXT.md` and `CHANGELOG.md` for every plugin.
- **Lint** — shellcheck (scripts), markdownlint (docs), actionlint (workflows).
- **Tests** — `bats` suite for the shell scripts.
- **Commit messages** — commitlint on every PR commit.
