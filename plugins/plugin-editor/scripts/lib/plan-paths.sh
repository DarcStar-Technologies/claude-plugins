#!/usr/bin/env bash
# plan-paths.sh — shared helpers for classifying /edit-plugin plan file paths.
# Sourced (never executed) by verify-repo.sh and scaffold-test.sh so both
# normalize a plan's files[] paths to the SAME plugin-relative form. Keeping this
# in one place stops the two from drifting — a divergence would let one scaffold
# a bundled test the other never runs, or vice versa.
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/lib/plan-paths.sh"

# norm_rel <plugin-dir> <path> — print <path> as a plugin-relative path. Strips a
# leading ./ and a leading <plugin-dir>/ prefix, then a leading <basename>/
# prefix — but only when that would NOT swallow a genuine plugin-relative path.
# The existence guard protects a plugin whose directory is basenamed like a
# component dir (e.g. one literally named `scripts`): `scripts/foo.sh` there must
# stay `scripts/foo.sh`, not be mis-stripped to `foo.sh`.
norm_rel() {
  local plugin_dir="${1%/}" p="${2#./}"
  local pd="${plugin_dir#./}"
  p="${p#"$pd"/}"
  local base="${plugin_dir##*/}" # fork-free basename
  if [[ -n "$base" && "$p" == "$base/"* && ! -e "$plugin_dir/$p" ]]; then
    p="${p#"$base"/}"
  fi
  printf '%s' "$p"
}
