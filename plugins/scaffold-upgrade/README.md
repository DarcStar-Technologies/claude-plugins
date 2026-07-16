# scaffold-upgrade

Report whether a plugin created from a template is behind the latest version of
that template — **read-only**. It reads the plugin's scaffold provenance, resolves
the latest template version, and tells you the semver gap and what changed.

## Usage

```text
/scaffold-upgrade [plugin-dir]        # defaults to the current directory
```

Or run the script directly:

```text
plugins/scaffold-upgrade/scripts/check-upgrade.sh <plugin-dir> [--json]
```

Example:

```text
$ /scaffold-upgrade plugins/semver
plugin:   semver
template: default  (scaffolded from v0.2.0)
latest:   v0.3.0  [marketplace:/…/claude-plugins]
status:   UPGRADE AVAILABLE (minor: v0.2.0 -> v0.3.0)

changes in the template since v0.2.0:
  ## [0.3.0] …
```

`--json` emits a machine-readable object
(`plugin`, `template`, `scaffoldedVersion`, `latestVersion`, `status`, `gap`,
`resolvedFrom`, `changed`).

## How it works

The plugin reads `<plugin-dir>/.claude-plugin/scaffold.json` (the `template`,
`templateVersion`, and `source` the scaffolder recorded), resolves the **latest**
version of that same template, and compares the two — reusing the `semver` plugin's
engine, resolved at run time (it is **not** vendored). See
[`CONTEXT.md`](./CONTEXT.md) for the resolution order and design notes.

It complements the repo-wide `scripts/scaffold-report.sh` drift gate but is
per-plugin, user-facing, works on standalone plugins, and shows *what changed*.

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
