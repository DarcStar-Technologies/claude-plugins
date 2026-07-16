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
| [`semver`](./plugins/semver) | Deterministic semver operations — validate, compare, bump, and next-version from Conventional Commits. |

> The plugins under `templates/` (e.g. `default`, `command-suite`) are internal
> reference **templates** the scaffolder builds from — list them with
> `scripts/list-templates.sh`. They are intentionally not published to the catalog.
>
> **Note on `plugin-forge`:** run inside a checkout of this repo it scaffolds and
> registers a plugin here; run anywhere else it scaffolds a standalone plugin
> (portable mode). See its [README](./plugins/plugin-forge/README.md).

## Roadmap

Planned plugins and larger work are tracked in [`ROADMAP.md`](./ROADMAP.md) and
[GitHub Issues](https://github.com/DarcStar-Technologies/claude-plugins/issues).

## Repository layout

```text
.
├─ .claude-plugin/marketplace.json   marketplace catalog
├─ plugins/
│  └─ <name>/                        one directory per published plugin
├─ templates/                        internal scaffolding templates (not published)
│  ├─ default/                       general-purpose reference template
│  └─ command-suite/                 archetype: command-only plugins
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

List the available templates, then scaffold a new plugin from one:

```text
scripts/list-templates.sh
plugins/plugin-forge/scripts/forge-scaffold.sh my-plugin --template command-suite --description "What it does" --register .
```

Then read [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the commit format, release
flow, and local checks. Guidance for AI assistants lives in
[`CLAUDE.md`](./CLAUDE.md).

## License

[MIT](./LICENSE) © DarcStar Technologies
