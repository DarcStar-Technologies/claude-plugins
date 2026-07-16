#!/usr/bin/env bats
#
# Tests for the semver plugin's engine (plugins/semver/scripts/semver.sh).

load helpers

setup() { S="$(repo_root_dir)/plugins/semver/scripts/semver.sh"; }

@test "validate accepts valid semver and rejects invalid" {
  run "$S" validate 1.2.3
  [ "$status" -eq 0 ]
  run "$S" validate 1.2.3-alpha.1+build
  [ "$status" -eq 0 ]
  run "$S" validate 1.2
  [ "$status" -ne 0 ]
  run "$S" validate "v1.2.3"
  [ "$status" -ne 0 ]
  run "$S" validate "1.2.3.4"
  [ "$status" -ne 0 ]
}

@test "compare orders numeric cores numerically" {
  run "$S" compare 0.10.0 0.9.0
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  [ "$("$S" compare 0.9.0 0.10.0)" = "-1" ]
  [ "$("$S" compare 2.0.0 1.9.9)" = "1" ]
  [ "$("$S" compare 1.2.3 1.2.3)" = "0" ]
}

@test "compare: release outranks pre-release; build metadata ignored" {
  [ "$("$S" compare 1.0.0 1.0.0-alpha)" = "1" ]
  [ "$("$S" compare 1.0.0-alpha 1.0.0)" = "-1" ]
  [ "$("$S" compare 1.0.0 1.0.0+build)" = "0" ]
  [ "$("$S" compare 1.0.0+a 1.0.0+b)" = "0" ]
}

@test "compare: pre-release identifier precedence (semver.org)" {
  [ "$("$S" compare 1.0.0-alpha 1.0.0-beta)" = "-1" ]
  [ "$("$S" compare 1.0.0-alpha.1 1.0.0-alpha.beta)" = "-1" ] # numeric < alphanumeric
  [ "$("$S" compare 1.0.0-alpha 1.0.0-alpha.1)" = "-1" ]      # fewer identifiers < more
  [ "$("$S" compare 1.0.0-alpha.10 1.0.0-alpha.2)" = "1" ]    # numeric compared numerically
}

@test "bump increments and resets lower components, dropping pre-release" {
  [ "$("$S" bump major 1.2.3)" = "2.0.0" ]
  [ "$("$S" bump minor 1.2.3)" = "1.3.0" ]
  [ "$("$S" bump patch 1.2.3)" = "1.2.4" ]
  [ "$("$S" bump major 1.2.3-rc.1)" = "2.0.0" ]
}

@test "major/minor/patch/diff extract and classify" {
  [ "$("$S" major 1.2.3)" = "1" ]
  [ "$("$S" minor 1.2.3)" = "2" ]
  [ "$("$S" patch 1.2.3)" = "3" ]
  [ "$("$S" diff 1.2.3 2.2.3)" = "major" ]
  [ "$("$S" diff 1.2.3 1.3.3)" = "minor" ]
  [ "$("$S" diff 1.2.3 1.2.4)" = "patch" ]
  [ "$("$S" diff 1.2.3 1.2.3)" = "none" ]
  [ "$("$S" diff 1.2.3 1.2.3-rc)" = "prerelease" ]
}

@test "invalid input is rejected by compare and bump" {
  run "$S" compare 1.2 1.2.3
  [ "$status" -ne 0 ]
  run "$S" bump minor nope
  [ "$status" -ne 0 ]
  run "$S" bump sideways 1.2.3
  [ "$status" -ne 0 ]
}

@test "next computes the version from Conventional Commits" {
  local w
  w="$(mktemp -d)"
  git -C "$w" init -q
  git -C "$w" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "chore: init"
  git -C "$w" tag base
  git -C "$w" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "fix: x"
  [ "$(cd "$w" && "$S" next 1.2.0 base..HEAD)" = "1.2.1" ]
  git -C "$w" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat: y"
  [ "$(cd "$w" && "$S" next 1.2.0 base..HEAD)" = "1.3.0" ]
  git -C "$w" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat!: z"
  [ "$(cd "$w" && "$S" next 1.2.0 base..HEAD)" = "2.0.0" ]
  rm -rf "$w"
}
