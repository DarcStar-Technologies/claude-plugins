# DarcStar Technologies · Claude Code Plugin Marketplace

A public, open-source marketplace of [Claude Code](https://claude.com/claude-code)
plugins, built to showcase the automation and tooling craft of
**DarcStar Technologies**.

Every plugin here is independently versioned (SemVer), self-documenting
(`CONTEXT.md` + `CHANGELOG.md`), and held to the same automated quality bar.

## Installing

Add the marketplace, then install a plugin (the marketplace is named `darcstar`):

```text
# Add this marketplace (GitHub owner/repo shorthand)
/plugin marketplace add DarcStar-Technologies/claude-plugins

# Install a plugin
/plugin install plugin-forge@darcstar
```

Or run `/plugin` to browse and install interactively. You can also add the
marketplace from a full git URL, or from a **local checkout** (useful for
development, and required for `plugin-forge` — see the note below):

```text
/plugin marketplace add https://github.com/DarcStar-Technologies/claude-plugins.git
/plugin marketplace add ./            # from inside a local clone
```

Manage it with:

```text
/plugin marketplace list              # list added marketplaces
/plugin marketplace update darcstar   # pull the latest catalog
/plugin marketplace remove darcstar
```

## Available plugins

| Plugin | Description |
| ------ | ----------- |
| [`plugin-forge`](./plugins/plugin-forge) | Generate a new plugin from a natural-language description; prompts for anything it can't infer. |

> `plugins/_template` is the reference/scaffold plugin. It is intentionally not
> published to the catalog.

> **Note on `plugin-forge`:** it authors new plugins *for this marketplace* by
> calling the repo's own `scripts/new-plugin.sh`, so `/forge` must run from a
> checkout of this repository. Clone it, launch Claude Code there, and add the
> marketplace with `/plugin marketplace add ./`.

## Roadmap

Planned plugins and larger work are tracked in [`ROADMAP.md`](./ROADMAP.md) and
[GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues) —
e.g. an [AI-assisted plugin scaffolder](https://github.com/DarcStar-Technologies/claude-plugins/issues/2).

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
├─ CONTRIBUTING.md                   conventions, commit format, release flow
└─ ROADMAP.md                        planned work (links to GitHub Issues)
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
