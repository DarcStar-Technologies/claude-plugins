#!/usr/bin/env bats
#
# plugin-editor's edit-kit-path.sh is the same resolver bootstrap template-editor
# carries (each consumer needs its own copy — it can't live in edit-kit, since you'd
# need to resolve edit-kit to run it). Its full behavior is covered by
# edit-kit-path.bats against template-editor's copy; here we guard that plugin-editor's
# copy has not drifted from that canonical, tested one, and smoke-test it resolves.

load helpers

@test "plugin-editor's edit-kit-path.sh is identical to template-editor's (tested) copy" {
  run diff -q \
    "$(repo_root_dir)/plugins/plugin-editor/scripts/edit-kit-path.sh" \
    "$(repo_root_dir)/plugins/template-editor/scripts/edit-kit-path.sh"
  [ "$status" -eq 0 ]
}

@test "resolves the real edit-kit from within the repo" {
  run "$(repo_root_dir)/plugins/plugin-editor/scripts/edit-kit-path.sh" \
    "$(repo_root_dir)/plugins/plugin-editor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/plugins/edit-kit/scripts" ]]
}
