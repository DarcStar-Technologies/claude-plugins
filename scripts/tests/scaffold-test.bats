#!/usr/bin/env bats
#
# Tests for plugin-editor/scripts/scaffold-test.sh — scaffolds a bundled bats
# stub for each newly created plugin script. Each test builds a throwaway plugin
# dir with a real scripts/foo.sh so the real repo is never touched. Key
# properties: it writes into the plugin's OWN scripts/tests/, is idempotent
# (never clobbers an existing test), skips non-top-level paths, and reports a
# non-zero exit for a missing script while still processing the others.

load helpers

setup() {
  ST="$(repo_root_dir)/plugins/plugin-editor/scripts/scaffold-test.sh"
  FIX="$(mktemp -d)"
  PDIR="$FIX/plugins/p"
  mkdir -p "$PDIR/scripts"
  printf '#!/usr/bin/env bash\necho hi\n' >"$PDIR/scripts/foo.sh"
  chmod +x "$PDIR/scripts/foo.sh"
}
teardown() { [[ -n "${FIX:-}" ]] && rm -rf "$FIX"; }

@test "writes a bundled scripts/tests/<name>.bats stub for a new script" {
  run "$ST" "$PDIR" scripts/foo.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"wrote"*"scripts/tests/foo.bats"* ]]
  [ -f "$PDIR/scripts/tests/foo.bats" ]
  run cat "$PDIR/scripts/tests/foo.bats"
  [[ "$output" == *"#!/usr/bin/env bats"* ]]
  [[ "$output" == *"setup()"* ]]
  [[ "$output" == *"@test"* ]]
  [[ "$output" == *"foo.sh"* ]]
}

@test "is idempotent: an existing (even hand-written) test is left untouched" {
  mkdir -p "$PDIR/scripts/tests"
  printf 'SENTINEL — do not clobber\n' >"$PDIR/scripts/tests/foo.bats"
  run "$ST" "$PDIR" scripts/foo.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists — leaving it untouched"* ]]
  run cat "$PDIR/scripts/tests/foo.bats"
  [ "$output" = "SENTINEL — do not clobber" ]
}

@test "normalizes ./-prefixed and plugin-dir-prefixed script paths" {
  run "$ST" "$PDIR" "./scripts/foo.sh" "$PDIR/scripts/foo.sh"
  [ "$status" -eq 0 ]
  [ -f "$PDIR/scripts/tests/foo.bats" ]
  # Second, dir-prefixed path resolves to the same file → idempotent skip, not a dupe.
  [[ "$output" == *"already exists — leaving it untouched"* ]]
}

@test "skips a nested (non-top-level) scripts path without failing" {
  mkdir -p "$PDIR/scripts/lib"
  printf '#!/usr/bin/env bash\ntrue\n' >"$PDIR/scripts/lib/bar.sh"
  run "$ST" "$PDIR" scripts/lib/bar.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a top-level scripts/*.sh — skipping"* ]]
  [ ! -f "$PDIR/scripts/tests/bar.bats" ]
}

@test "reports a non-zero exit for a missing script but still processes the rest" {
  run "$ST" "$PDIR" scripts/ghost.sh "$PDIR/scripts/foo.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"script not found"*"ghost.sh"* ]]
  # The valid path in the same invocation was still scaffolded.
  [ -f "$PDIR/scripts/tests/foo.bats" ]
}

@test "errors on usage: missing plugin-dir, and no script paths" {
  run "$ST"
  [ "$status" -ne 0 ]
  run "$ST" "$PDIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no script paths given"* ]]
}
