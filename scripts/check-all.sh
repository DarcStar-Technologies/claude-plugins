#!/usr/bin/env bash
# Run every structural repository check. Used by CI and available locally as
# `npm run check`. Fails on the first failing check.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

info "validating manifests"
"$SCRIPT_DIR/validate-manifests.sh"

info "checking plugin documentation"
"$SCRIPT_DIR/check-plugin-docs.sh"

info "checking versions & changelogs"
"$SCRIPT_DIR/check-versions.sh"

info "all repository checks passed"
