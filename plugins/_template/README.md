# _template

Reference plugin for the DarcStar Technologies marketplace. It is the canonical
example of the layout every plugin follows and the template that plugin-forge's
scaffolder copies from. It is intentionally **not** listed in the public
marketplace catalog (its name is prefixed with `_`).

## What it demonstrates

- A slash command (`commands/hello.md`) that delegates to a deterministic shell
  script instead of spending model tokens on trivial work.
- A subagent (`agents/example-reviewer.md`) pinned to the **minimum capable
  model** (`haiku`) for a bounded task.
- A skill (`skills/example-skill/SKILL.md`).
- A mechanized script (`scripts/example.sh`).
- The required documentation set: `CONTEXT.md`, `CHANGELOG.md`, `README.md`.

## Create a new plugin from this template

```text
plugins/plugin-forge/scripts/forge-scaffold.sh my-plugin --description "What it does" --register .
scripts/check-all.sh
```

## Development

See [`CONTEXT.md`](./CONTEXT.md) for design notes.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
