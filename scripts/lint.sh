#!/usr/bin/env bash
# Convenience wrapper that runs the available linters over the repo. Each linter
# is optional locally: a missing tool is reported and skipped rather than fatal.
# CI installs and enforces them all.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

root="$(repo_root)"
status=0

if command -v shellcheck >/dev/null 2>&1; then
  info "shellcheck"
  shellcheck "$root"/scripts/*.sh "$root"/scripts/lib/*.sh || status=1
else
  warn "shellcheck not installed; skipping"
fi

if command -v shfmt >/dev/null 2>&1; then
  info "shfmt (diff)"
  shfmt -i 2 -ci -d "$root/scripts" || status=1
else
  warn "shfmt not installed; skipping"
fi

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  info "markdownlint"
  (cd "$root" && markdownlint-cli2) || status=1
elif command -v npx >/dev/null 2>&1; then
  info "markdownlint (npx)"
  (cd "$root" && npx --no-install markdownlint-cli2) || status=1
else
  warn "markdownlint-cli2 not available; skipping"
fi

if command -v actionlint >/dev/null 2>&1; then
  info "actionlint"
  (cd "$root" && actionlint) || status=1
else
  warn "actionlint not installed; skipping"
fi

[[ "$status" -eq 0 ]] && info "lint OK"
exit "$status"
