# DarcStar Technologies · Claude Code Plugin Marketplace

A public, open-source marketplace of [Claude Code](https://claude.com/claude-code)
plugins, built to showcase the automation and tooling craft of
**DarcStar Technologies**.

Every plugin here is independently versioned (SemVer), self-documenting
(`CONTEXT.md` + `CHANGELOG.md`), and held to the same automated quality bar.

## Install the marketplace

```text
/plugin marketplace add DarcStar-Technologies/claude-plugins
/plugin install <plugin-name>@darcstar
```

## Available plugins

| Plugin | Description |
| ------ | ----------- |
| _(none published yet — this is the foundation release)_ | |

> `plugins/_template` is the reference/scaffold plugin. It is intentionally not
> published to the catalog.

## Repository layout

```text
.
├─ .claude-plugin/marketplace.json   marketplace catalog
├─ plugins/
│  ├─ _template/                     reference plugin & scaffold source
│  └─ <name>/                        one directory per published plugin
├─ templates/                        token files used by new-plugin.sh
├─ scripts/                          mechanized validation & tooling (+ bats tests)
├─ .github/workflows/                CI gates and release automation
├─ CHANGELOG.md                      repo-level (tooling/structure) changelog
└─ CONTRIBUTING.md                   conventions, commit format, release flow
```

## Design principles

- **Mechanize the deterministic.** Anything that does not need reasoning is a
  shell script in `scripts/` — tested with `bats`, not left to a model.
- **Minimum capable model.** Subagents and commands declare the smallest model
  (`haiku` → `sonnet` → `opus`) that still produces correct results.
- **Automate the standards.** Conventional Commits drive versioning and
  changelogs; pre-commit hooks and CI enforce structure so quality is
  repeatable, not a matter of discipline.

## Contributing

Start a new plugin from the template:

```text
scripts/new-plugin.sh my-plugin --description "What it does"
```

Then read [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the commit format, release
flow, and local checks. Guidance for AI assistants lives in
[`CLAUDE.md`](./CLAUDE.md).

## License

[MIT](./LICENSE) © DarcStar Technologies
