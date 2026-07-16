# command-suite

Reference template for the DarcStar Technologies marketplace. It is the canonical
example of a plugin that exposes **several related slash commands backed by one
shared, deterministic script**. Like `default`, it lives under `templates/` and is
intentionally **not** listed in the public catalog.

## What it demonstrates

- Two slash commands (`commands/upper.md`, `commands/count.md`) that are thin
  wrappers over a single mechanized backend.
- A shared dispatcher script (`scripts/suite.sh`) with one subcommand per command
  — the *command-suite* pattern: many entry points, one deterministic backend,
  zero model cost.
- The required documentation set: `CONTEXT.md`, `CHANGELOG.md`, `README.md`.

Use this template (instead of the kitchen-sink `default`) when a plugin is
primarily a set of related commands with no agents or skills.

## Create a new plugin from this template

```text
plugins/plugin-forge/scripts/forge-scaffold.sh my-suite --template command-suite --description "What it does" --register .
scripts/check-all.sh
```

To see every available template and pick one:

```text
scripts/list-templates.sh
```

## Development

See [`CONTEXT.md`](./CONTEXT.md) for design notes.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
