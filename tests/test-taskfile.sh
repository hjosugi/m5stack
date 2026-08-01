#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

[[ -f $REPO_ROOT/Taskfile.yml ]] || {
  echo "Taskfile.ymlがありません。" >&2
  exit 1
}
[[ ! -e $REPO_ROOT/Makefile ]] || {
  echo "Makefileが残っています。" >&2
  exit 1
}

task_list=$(task --dir "$REPO_ROOT" --list-all)
expected_tasks=(
  check
  device:detect
  device:select
  arduino:setup
  arduino:build
  arduino:matrix
  cardputer:screen-link:build
  stackchan:factory:setup
  stackchan:factory:build
  stackchan:screen-link:build
  host:screen-link:setup
  host:screen-link:run
  host:screen-link:status
  host:stackchan:status
)
for task_name in "${expected_tasks[@]}"; do
  grep -Fq -- "* $task_name:" <<< "$task_list" || {
    printf '必須taskがありません: %s\n' "$task_name" >&2
    exit 1
  }
done

task --silent --dir "$REPO_ROOT" list > /dev/null
if task --dir "$REPO_ROOT" device:select > /dev/null 2>&1; then
  echo "MODELなしのdevice:selectが成功しました。" >&2
  exit 1
fi
if task --dir "$REPO_ROOT" arduino:ci > /dev/null 2>&1; then
  echo "TARGETなしのarduino:ciが成功しました。" >&2
  exit 1
fi

printf 'Taskfile tests: OK\n'
