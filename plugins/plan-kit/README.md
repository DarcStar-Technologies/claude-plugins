# plan-kit

The shared, deterministic **plan-flow toolkit** for the DarcStar marketplace. It has
**no user command** — it is a *provider* plugin whose script is resolved and run by
[`plan-confirm-apply`](../../templates/plan-confirm-apply/)-derived plugins, the same way
`edit-kit` provides the edit-flow scripts or `semver` provides its versioning engine. One
canonical implementation, no vendored copies.

## What it provides

| Script | Does |
| ------ | ---- |
| `scripts/validate-plan.sh` | Validate a planner's JSON plan shape before the command presents or acts on it — `summary` string, `actions[]` items each with a string `path` and an `action` in the allowed vocabulary, `questions[]` array. Names the first violation; tolerates domain-specific extra fields. |

### `validate-plan.sh`

```text
validate-plan.sh [--field name] [--actions a,b,c] [plan-file]
```

- `--field` — the top-level array of change items to validate (default `actions`).
  A consumer whose planner names it differently passes it, e.g. `--field files` for the
  edit-flow plan shape.
- `--actions` — comma-separated allowed values for each `<field>[].action`
  (default `create,modify,delete`). A consumer whose plans use a different vocabulary
  passes its own, e.g. `--actions add,keep,update,delete`.
- `plan-file` — read the plan JSON from this file (default: stdin).

Exits `0` when the plan is valid; exits `1` naming the first violation on stderr
(malformed JSON, a missing/mistyped field, or an illegal action).

## How consumers resolve it

Resolve the script at run time in this precedence (mirroring `$EDIT_KIT_DIR` /
`$SEMVER_BIN`), so nothing is vendored:

1. `$PLAN_KIT_DIR/<script>` when the `PLAN_KIT_DIR` environment variable is set;
2. `<marketplace-ancestor>/plugins/plan-kit/scripts/<script>` — walk up from the caller to
   the nearest ancestor containing `.claude-plugin/marketplace.json`;
3. `<script>` on `PATH`.

A plugin that depends on plan-kit declares it in `plugin.json` `dependencies` (so Claude
Code auto-installs it) and bundles a small `provider-path.sh` locator implementing the
precedence above.

## Development

See [`CONTEXT.md`](./CONTEXT.md) for the design and [`CHANGELOG.md`](./CHANGELOG.md)
for release history.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
