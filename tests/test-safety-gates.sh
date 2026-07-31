#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

expect_rejected() {
  local description=$1
  shift
  if "$@" > /dev/null 2>&1; then
    printf '%s が明示許可なしで成功しました。\n' "$description" >&2
    exit 1
  fi
}

# いずれも引数検査で終了し、環境読込み、ポート操作、リセットへ到達しない。
expect_rejected "Flashバックアップ" "$REPO_ROOT/scripts/backup-flash.sh"
expect_rejected "Arduino書込み" "$REPO_ROOT/scripts/upload.sh"
expect_rejected "コミュニティ版書込み" "$REPO_ROOT/scripts/install-community-stackchan.sh"
expect_rejected "シリアルモニター" "$REPO_ROOT/scripts/monitor.sh"
expect_rejected "Flash復旧" "$REPO_ROOT/scripts/restore-flash.sh"

# Makeの短縮ターゲットも、危険操作を直接呼ばず使用方法を案内するだけにする。
for target in backup upload install-community monitor restore; do
  expect_rejected "make $target" make --no-print-directory -C "$REPO_ROOT" "$target"
done

printf 'safety gate tests: OK\n'
