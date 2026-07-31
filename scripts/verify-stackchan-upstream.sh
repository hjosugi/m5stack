#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command cmp

top_level_only=false
if [[ ${1:-} == --top-level && $# == 1 ]]; then
  top_level_only=true
elif (($# > 0)); then
  die "使用方法: $0 [--top-level]"
fi

upstream_root="$M5_REPO_ROOT/.local/upstream"
verified=0

while IFS='|' read -r name url _ref commit relative_path; do
  [[ -z $name || $name == \#* ]] && continue
  if [[ $top_level_only == true && $relative_path == */* ]]; then
    continue
  fi

  directory="$upstream_root/$relative_path"
  [[ -d $directory/.git ]] || die "$name のcheckoutがありません: $directory"
  actual_commit=$(git -C "$directory" rev-parse HEAD)
  [[ $actual_commit == "$commit" ]] || die "$name のHEAD不一致: expected=$commit actual=$actual_commit"
  remote_url=$(git -C "$directory" remote get-url origin)
  [[ ${remote_url%.git} == "${url%.git}" ]] || die "$name のorigin不一致: $remote_url"

  if [[ $name == xiaozhi-esp32 ]]; then
    patch_file="$upstream_root/StackChan/firmware/patches/xiaozhi-esp32.patch"
    git -C "$directory" apply --reverse --check "$patch_file" > /dev/null || die "xiaozhi-esp32に公式パッチが正しく適用されていません。"
    git -C "$directory" diff --binary | cmp -s "$patch_file" - || die "xiaozhi-esp32の変更が公式パッチと完全一致しません。"
    [[ -z $(git -C "$directory" ls-files --others --exclude-standard) ]] || die "xiaozhi-esp32に未追跡ファイルがあります。"
  elif [[ -n $(git -C "$directory" status --porcelain) ]]; then
    die "$name のcheckoutに想定外の変更があります。"
  fi
  ((verified += 1))
done < "$M5_REPO_ROOT/config/upstream.lock"

log "上流checkoutを検証しました: $verified 件"
