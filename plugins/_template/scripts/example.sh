#!/usr/bin/env bash
# Deterministic greeting used by the /hello command. Demonstrates a mechanized
# step: no LLM required, fully testable, zero model cost.
set -euo pipefail

name="${1:-world}"
printf 'Hello, %s! — from the DarcStar plugin template.\n' "$name"
