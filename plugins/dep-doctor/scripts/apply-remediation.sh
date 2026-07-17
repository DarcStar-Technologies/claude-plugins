#!/usr/bin/env bash
# apply-remediation.sh — the ONLY mutating step of dep-doctor, run only after the user
# has confirmed the plan. It installs missing dependencies, but STRICTLY: it takes
# STRUCTURED actions (an installer + a package name), never free-form command strings,
# so a plan can't smuggle in an arbitrary command. It enforces an allow-list of
# non-privileged, user-scoped installers and validates every package name; anything
# outside that (sudo, system package managers, plugin installs, MCP setup) is refused
# here and must be done by the user manually.
#
# Input: a JSON array of actions on <file> arg or stdin, each:
#   {installer:"npm|pip|pip3|pipx|cargo|go", package:"<name>"}
#
# Flags: --dry-run  print the exact command per action, run nothing.
#
# Exit: 0 if every action succeeded (or dry-run); 1 if any failed or was refused.
set -euo pipefail

die() {
  printf 'apply-remediation: %s\n' "$*" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || die "jq is required"

dry_run=0
file=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -*) die "unknown option: $arg" ;;
    *) file="$arg" ;;
  esac
done

input="$(cat -- "${file:-/dev/stdin}")"
jq -e 'type == "array"' >/dev/null 2>&1 <<<"$input" ||
  die "input must be a JSON array of {installer, package} actions"
jq -e 'all(.[]; type == "object")' >/dev/null 2>&1 <<<"$input" ||
  die "every action must be a JSON object with an installer and package"

# A package name must be a plain package token. Beyond the allowed character set it must
# NOT: start with '-' (else it is an installer FLAG — argument injection like
# `npm install -g --foo`), start with '/' or './' or contain '..' (else it is a local
# PATH — installing a local dir runs its lifecycle scripts, i.e. arbitrary code). Scoped
# npm (`@scope/pkg`) and Go module paths (`host/mod@ver`) keep an internal '/' legitimately.
safe_pkg() {
  local p="$1"
  [[ -n "$p" ]] || return 1
  [[ "$p" == -* ]] && return 1
  [[ "$p" == /* || "$p" == ./* ]] && return 1
  [[ "$p" == *".."* ]] && return 1
  [[ "$p" =~ ^[A-Za-z0-9@._/+-]+$ ]]
}

# Build the argv for an allow-listed installer (echoed NUL-separated). Refused installers
# return non-zero and print nothing.
build_cmd() { # <installer> <package>  -> prints argv, one per line
  local installer="$1" pkg="$2"
  case "$installer" in
    npm) printf '%s\n' npm install -g "$pkg" ;;
    pip) printf '%s\n' pip install --user "$pkg" ;;
    pip3) printf '%s\n' pip3 install --user "$pkg" ;;
    pipx) printf '%s\n' pipx install "$pkg" ;;
    cargo) printf '%s\n' cargo install "$pkg" ;;
    go) printf '%s\n' go install "$pkg" ;;
    *) return 1 ;;
  esac
}

count="$(jq 'length' <<<"$input")"
status=0

for ((i = 0; i < count; i++)); do
  installer="$(jq -r ".[$i].installer // \"\"" <<<"$input")"
  pkg="$(jq -r ".[$i].package // \"\"" <<<"$input")"

  if ! safe_pkg "$pkg"; then
    printf 'REFUSED: package %q is not a plain package name — install it manually.\n' "$pkg" >&2
    status=1
    continue
  fi
  if ! mapfile -t argv < <(build_cmd "$installer" "$pkg") || [[ "${#argv[@]}" -eq 0 ]]; then
    printf 'REFUSED: installer %q is not allow-listed (allowed: npm pip pip3 pipx cargo go) — do it manually.\n' "$installer" >&2
    status=1
    continue
  fi
  if ! command -v "${argv[0]}" >/dev/null 2>&1; then
    printf 'SKIPPED: %s not installed, cannot run: %s\n' "${argv[0]}" "${argv[*]}" >&2
    status=1
    continue
  fi

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'DRY-RUN: %s\n' "${argv[*]}"
    continue
  fi

  printf '==> %s\n' "${argv[*]}"
  if "${argv[@]}"; then
    printf 'OK: installed %s via %s\n' "$pkg" "$installer"
  else
    printf 'FAILED: %s\n' "${argv[*]}" >&2
    status=1
  fi
done

exit "$status"
