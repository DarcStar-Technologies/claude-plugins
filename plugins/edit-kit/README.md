# edit-kit

The shared, deterministic **edit-flow toolkit** for the DarcStar marketplace. It has
**no user command** — it is a *provider* plugin whose scripts are resolved and run by
other plugins (`plugin-editor`, `template-editor`), the same way `sync-version.sh`
resolves the `semver` plugin's engine or `check-template.sh` resolves
`scaffold-upgrade`'s. One canonical implementation, no vendored copies.

## What it provides

| Script | Does |
| ------ | ---- |
| `scripts/check-structure.sh` | Validate a target dir's own structure — manifest fields + semver, name-vs-dir, required docs, changelog shape, `shellcheck` its scripts. |
| `scripts/update-changelog.sh` | Insert a bullet under `## [Unreleased] > ### <category>` in a target's `CHANGELOG.md`. |
| `scripts/sync-version.sh` | Context-aware versioning — release-please guidance vs. a standalone hand-bump (via the `semver` engine). |
| `scripts/scaffold-test.sh` | Write a bundled, skipped `scripts/tests/<name>.bats` stub for each newly created target script. |
| `scripts/verify-repo.sh` | Post-apply cross-checks — the marketplace's `check-all.sh` + the target's `bats` tests (scoped & advisory). |
| `scripts/lib/plan-paths.sh` | Shared `norm_rel` plan-path normalizer (sourced by the above). |

Every script operates on a **target directory** (a plugin or a template) passed as its
first argument, and stays inside that directory's concerns.

## How consumers resolve it

Resolve a script at run time in this precedence (mirroring `$SEMVER_BIN` /
`$CHECK_UPGRADE_BIN`), so nothing is vendored:

1. `$EDIT_KIT_DIR/<script>` when the `EDIT_KIT_DIR` environment variable is set;
2. `<marketplace-ancestor>/plugins/edit-kit/scripts/<script>` — walk up from the target
   (or the caller) to the nearest ancestor containing `.claude-plugin/marketplace.json`;
3. `<script>` on `PATH`.

## Development

See [`CONTEXT.md`](./CONTEXT.md) for the design and [`CHANGELOG.md`](./CHANGELOG.md)
for release history.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
