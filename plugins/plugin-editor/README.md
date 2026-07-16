# plugin-editor

Make a change to an existing plugin — add a feature, change a behavior, fix a bug,
or remove a capability — with the safety rails handled for you: clarifying
questions, template-conformance and repo-verification checks, a changelog entry, the
right version bump, and a reload hint if the plugin is active in your session.

## Usage

```text
/edit-plugin [--dry-run] [--plugin=<dir>] [--type=add|change|fix|remove] [<plugin-dir>] [— <what you want to change>]
```

Omit `<plugin-dir>` (when the current directory isn't itself a plugin) and it
lists the marketplace's plugins for you to pick from.

If you don't spell out the change, `/edit-plugin` runs **guided intake**: it asks the
**change type** (add a feature / change a behavior / fix a bug / remove a capability),
then offers a short list of **specific suggestions tailored to that plugin and change
type** (always with an option to describe your own instead). A missing *plugin* is a
separate matter, handled just before by the picker.

Supply flags to skip what you've already decided: `--plugin=<dir>` names the plugin
and skips the picker; `--type=<...>` sets the change type and skips the change-type
question. Fully describing the change in the invocation skips guided intake entirely
(a supplied `--type=` still fixes the change type for the plan). The flow resumes from
whatever you've already given, never re-asking it.

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
/edit-plugin --type=fix plugins/semver          # asks for a fix-specific suggestion
/edit-plugin --plugin=plugins/semver --type=add # both known; jumps to suggestions
```

The flow is **plan → confirm → apply**: it never edits anything until you approve
the plan.

1. If the change isn't fully described, **guided intake** fills the gap — it asks the
   change type (skipped when `--type=` set it), then offers plugin-specific
   suggestions (or your own). A missing plugin is resolved just before, by the picker.
2. The `edit-planner` agent reads the plugin (and its template, if any) and returns
   a concrete plan — files to touch, a changelog entry, the version impact, and a
   note if the change diverges from the plugin's template.
3. You review and approve.
4. It applies the edits, then **re-reads every changed file to confirm each planned
   change actually landed** (fixing or surfacing anything that didn't), and runs:
   - `check-template.sh` — structural validation **and** template-drift,
   - `update-changelog.sh` — records the change under `[Unreleased]`,
   - `sync-version.sh` — bumps the version (or, in a release-please repo, tells you
     the Conventional Commit to land),
   - `scaffold-test.sh` — for each newly created `scripts/*.sh`, scaffolds a bundled
     `scripts/tests/<name>.bats` stub (idempotent — never overwrites an existing one),
     so `verify-repo.sh`'s bundled-tests check covers it,
   - `verify-repo.sh` — advisory cross-checks: the marketplace's own `check-all.sh`
     (skipped cleanly outside a marketplace) and the plugin's `bats` tests; it blocks
     only on the plugin's own bundled tests, and surfaces repo-wide / centralized-test
     issues as warnings to review before merging,
   - `check-install-status.sh` — if the plugin is installed in this session,
     suggests `/plugin update` + `/reload-plugins`.
5. It finishes with a **summary** of every file touched, what changed, and the
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
