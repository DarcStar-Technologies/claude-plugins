# plugin-editor

Make a change to an existing plugin — add a feature, change a behavior, fix a bug,
or remove a capability — with the safety rails handled for you: clarifying
questions, template-conformance checks, a changelog entry, the right version bump,
and a reload hint if the plugin is active in your session.

## Usage

```text
/edit-plugin [--dry-run] [<plugin-dir>] — <what you want to change>
```

Omit `<plugin-dir>` (when the current directory isn't itself a plugin) and it
lists the marketplace's plugins for you to pick from.

Prefix the command with `--dry-run` to **preview** the plan — the locate and plan
steps run (it may still show the picker or ask clarifying questions to build an
accurate preview), the plan is shown, and then the command stops. No edits are
applied, no changelog entry is written, no version is bumped, and no other script
runs. Re-run without the leading `--dry-run` to apply it. (`--dry-run` only counts
as the flag in the leading position — inside your change text, e.g. "add a
`--dry-run` flag", it's treated as literal content.)

Examples:

```text
/edit-plugin plugins/semver — add a `--quiet` flag to the compare subcommand
/edit-plugin ./my-plugin — remove the deprecated /legacy command
```

The flow is **plan → confirm → apply**: it never edits anything until you approve
the plan.

1. The `edit-planner` agent reads the plugin (and its template, if any) and returns
   a concrete plan — files to touch, a changelog entry, the version impact, and a
   note if the change diverges from the plugin's template.
2. You review and approve.
3. It applies the edits, then **re-reads every changed file to confirm each planned
   change actually landed** (fixing or surfacing anything that didn't), and runs:
   - `check-template.sh` — structural validation **and** template-drift,
   - `update-changelog.sh` — records the change under `[Unreleased]`,
   - `sync-version.sh` — bumps the version (or, in a release-please repo, tells you
     the Conventional Commit to land),
   - `check-install-status.sh` — if the plugin is installed in this session,
     suggests `/plugin update` + `/reload-plugins`.
4. It finishes with a **summary** of every file touched, what changed, and the
   changelog/version outcome.

## How it works

The reasoning parts (interpreting the request, editing code, judging template
divergence) run on a model; everything deterministic is a tested shell script under
`scripts/`. Version math reuses the `semver` plugin and the template check reuses
`scaffold-upgrade` — both resolved at run time, never vendored. See
[`CONTEXT.md`](./CONTEXT.md).

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
