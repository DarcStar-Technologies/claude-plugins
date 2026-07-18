# scaffold-retarget

Upgrade **or downgrade** an already-scaffolded plugin to a different version of the
reference template it was created from — the mutating companion to the read-only
[`scaffold-upgrade`](../scaffold-upgrade/) (which only reports the gap).

## Usage

```text
/scaffold-retarget [--dry-run] [<plugin-dir>] [<version>|latest]
```

- Omit the plugin and it lists retargetable plugins (those with scaffold provenance) to
  pick from. Omit the version and it asks which one — `latest`, or any specific version
  (a lower version is a valid **downgrade**).
- It then, via a **plan → confirm → apply** flow:
  1. materializes the plugin's current template version and the target version,
  2. runs a **3-way diff** of the component files (base template vs your files vs target),
  3. **plans** the per-file changes — surfacing any conflict (you customized a file the
     template also changed) for you to resolve, never overwriting silently,
  4. **validates** the plan's shape via the shared [`plan-kit`](../plan-kit/) provider,
  5. **confirms** with you, then **applies**: re-renders the chosen template files with
     the plugin's own identity, updates `.claude-plugin/scaffold.json`, and records a
     CHANGELOG entry.
- `--dry-run` shows the plan and changes nothing.

## What it does not do

- It never touches `plugin.json`'s name/description or the plugin's README/CONTEXT —
  identity is preserved.
- It does not bump the plugin's `plugin.json` version; release-please does that from the
  Conventional Commit you land after retargeting.
- It only changes the *version* of the recorded template — switching to a different
  template means re-scaffolding.

## Development

See `CONTEXT.md` for design notes and `CHANGELOG.md` for release history.
