# semver

Deterministic [Semantic Versioning 2.0.0](https://semver.org/) operations for any
project — validate, compare, bump, and compute the next version from Conventional
Commits. The work is a shell script, so answers are exact and reproducible.

## Installation

```text
/plugin marketplace add DarcStar-Technologies/claude-plugins
/plugin install semver@darcstar
```

## Usage

```text
/semver validate 1.2.3-rc.1
/semver compare 1.10.0 1.9.0        # -> 1  (first is newer)
/semver bump minor 1.2.3            # -> 1.3.0
/semver diff 1.2.3 2.0.0            # -> major
/semver next 1.4.0 v1.4.0..HEAD     # next version from Conventional Commits
```

Subcommands: `validate`, `compare`, `bump <major|minor|patch>`,
`major`/`minor`/`patch`, `diff`, `next <current> <git-range>`.

Precedence follows semver.org: numeric core compared numerically (so `0.10.0` >
`0.9.0`), a release outranks a pre-release, pre-release identifiers compare per
spec, and build metadata is ignored.

## Development

See [`CONTEXT.md`](./CONTEXT.md) for design notes and
[`CHANGELOG.md`](./CHANGELOG.md) for release history.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
