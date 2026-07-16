# plugin-forge

Generate a new marketplace plugin from a natural-language description. plugin-forge
infers the name, components, tools, and minimum-capable models, defaults to the
current template version, and asks you about anything it can't confidently infer —
then hands the mechanical work to `scripts/new-plugin.sh`.

## Installation

```text
/plugin marketplace add DarcStar-Technologies/claude-plugins
/plugin install plugin-forge@darcstar
```

## Usage

Run inside a checkout of the `claude-plugins` marketplace:

```text
/forge a plugin with a /changelog command that summarizes git commits since the last tag
```

plugin-forge will:

1. Plan the plugin from your description (via the `plugin-planner` agent).
2. Ask you about anything ambiguous, and confirm the plan.
3. Scaffold and register it with `scripts/new-plugin.sh`.
4. Fill in the components and validate with `scripts/check-all.sh`.

## Notes & limitations

- Must be run from the marketplace repository — it calls the repo's scripts.
- Only the **current** template version is supported today; requesting a specific
  older version is a roadmap item (see [`CONTEXT.md`](./CONTEXT.md)).

## Development

See [`CONTEXT.md`](./CONTEXT.md) for the design and
[`CHANGELOG.md`](./CHANGELOG.md) for release history.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
