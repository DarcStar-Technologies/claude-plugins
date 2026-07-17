# dep-doctor

Check whether a plugin's **dependencies** are installed correctly — command-line tools,
libraries, MCP servers, and other plugins — and, **with your explicit confirmation**,
install or fix what's missing. Built on the
[`plan-confirm-apply`](../../templates/plan-confirm-apply/) archetype: **verification is
read-only; installing is a mutation that never happens without a go-ahead.**

## Usage

```text
/dep-doctor [--check-only] [--dry-run] [<plugin-dir>]
```

Omit the plugin and it lists the marketplace's plugins to pick from. It then:

1. **reads** the target's declared `dependencies` (the first-class `plugin.json` field) as
   authoritative plugin deps, and **infers** the rest (CLI tools, libraries, MCP servers)
   from its manifest, docs, and scripts — e.g. `command -v <tool>`, named MCP servers,
   sibling-plugin reuse,
2. **checks** each with the read-only `check-deps.sh` (OK / MISSING / WRONG-VERSION /
   UNKNOWN),
3. **plans** remediation for the rest, then **confirms** with you and **applies** only the
   safe installs, and
4. **re-verifies**.

- `--check-only` — verify and report only; never propose or apply remediation.
- `--dry-run` — show the plan and the exact install commands; apply nothing.

## Safety

- Verification is entirely read-only.
- Installing happens **only after explicit approval** and only through an **allow-list**
  of non-privileged, user-scoped installers (`npm`, `pip`/`pip3`, `pipx`, `cargo`, `go`).
- Anything else — `sudo`, system package managers, plugin installs (`/plugin install …`),
  MCP server setup — is **refused** by the installer and surfaced as a **manual step**
  with the exact command for you to run.
- It only ever touches the **environment**, never the target plugin's own files.

## Declaring dependencies

The best signal is the first-class **`dependencies` array in `plugin.json`** — Claude
Code's own plugin-dependency manifest. dep-doctor reads it as the **authoritative** source
of plugin-kind dependencies: a bare string `"foo"` is checked for presence, and an object
`{"name":"foo","version":">=1.2.0"}` is checked against the installed version (ranges:
`>=`, `>`, `<=`, `<`, `=`/exact, `^`, `~`). CLI tools, libraries, and MCP servers aren't
expressible there, so dep-doctor still infers those from the plugin's files.

A plugin author may also add a legacy `.claude-plugin/dependencies.json` — a JSON array of
`{kind, name, …}` descriptors (see `scripts/check-deps.sh`) — whose entries take
precedence over inference.

## How it works

The reasoning (inferring dependencies, planning remediation) runs on a model; the checking
and installing are tested shell scripts. See [`CONTEXT.md`](./CONTEXT.md).

---

Part of the [DarcStar Technologies plugin marketplace](https://github.com/DarcStar-Technologies/claude-plugins).
Licensed under [MIT](../../LICENSE).
