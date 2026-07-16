# scaffold-upgrade — Context

> Orientation for humans and AI assistants working on this plugin.

## Purpose

Tell someone whether a plugin that was scaffolded from a template is **behind**
the latest version of that template — the semver gap and what changed — so they
can decide to upgrade. It is **report-only**: it never edits the plugin.

## Mental model

Every plugin the scaffolder produces carries `.claude-plugin/scaffold.json`
recording the `template` it came from, the `templateVersion` at that moment, and
the `source` it was fetched from. This plugin closes the loop: read that
provenance, find the template's **current** version, and compare.

```text
scaffold.json (template, templateVersion, source)
        │
        ├─ resolve the template's latest version + CHANGELOG
        └─ compare with semver  ->  up-to-date | upgrade-available (gap) | ahead
```

It is the per-plugin, portable counterpart to the repo-wide
`../../scripts/scaffold-report.sh` drift gate.

## Components

| Path | Type | Responsibility |
| ---- | ---- | -------------- |
| `scripts/check-upgrade.sh` | Shell | The whole engine: read provenance, resolve latest, compare, extract "what changed". |
| `commands/scaffold-upgrade.md` | Slash command | `/scaffold-upgrade [dir]` — run the script, report verbatim. |

There is deliberately **no model**: the work is fully deterministic, so it lives
in a script and the command is a thin wrapper (the marketplace's "mechanize the
deterministic / minimum-capable model" principle — the model here is *none*).

## How "latest" is resolved

From the recorded `source`, in order (first hit wins):

1. **Ancestor marketplace** — walk up from the plugin dir to a checkout whose
   `.claude-plugin/marketplace.json` sits beside `templates/<name>`. The common
   in-repo case; no network.
2. **A local path** embedded in the source (`local:<path>` / `repo:<localpath>`).
3. **Release tags** — `git ls-remote --tags <repo> '<name>-v*'`, pick the highest
   via semver, and shallow-fetch that tag for the CHANGELOG. The repo is the one in
   the source (`default:<url>` / a custom `repo:`) or the DarcStar default for a
   `tag:` source.

`SCAFFOLD_UPGRADE_DEFAULT_REPO` overrides the default upstream (used by the tests
to point at a local fixture repo instead of the network).

## Reusing the semver engine (no vendored copy)

Version math reuses the `semver` plugin's `semver.sh` — the single source of truth
for the repo's version logic. It is resolved **at run time**, never copied:
`$SEMVER_BIN` → a marketplace ancestor's `plugins/semver/scripts/semver.sh` →
`semver.sh` on `$PATH`. If none is found the tool exits with a clear message rather
than guessing. (A symlink would dangle once the plugin is installed standalone —
it escapes the plugin's install directory — so runtime resolution is used instead.)

## Gotchas

- **"What changed" reads the template's own CHANGELOG** between the recorded and
  latest headings — no git history required. It assumes the template's changelog
  lists every released version (release-please guarantees this); a recorded version
  missing from the changelog falls back to showing all newer entries.
- **Portable use needs the semver engine reachable** (`SEMVER_BIN` or `semver.sh`
  on `PATH`) — it is not bundled, by design.
- **Read-only**: the tool only reads the target plugin. Any actual upgrade is left
  to the human (a future version could assist with it).

## References

- Repo drift gate: `../../scripts/scaffold-report.sh`
- The semver engine it reuses: `../semver/scripts/semver.sh`
