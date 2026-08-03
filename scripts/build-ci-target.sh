#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ $# == 1 ]] || die "使用方法: $0 <FQBN|cardputer-screen-link>"
target=$1

if [[ $target == cardputer-screen-link ]]; then
  "$M5_REPO_ROOT/cardputer/screen-link/build.sh" --ci
  exit 0
fi

supported=false
while IFS= read -r fqbn || [[ -n $fqbn ]]; do
  [[ -z $fqbn || $fqbn == \#* ]] && continue
  if [[ $target == "$fqbn" ]]; then
    supported=true
    break
  fi
done < "$M5_REPO_ROOT/config/ci-boards.txt"
[[ $supported == true ]] || die "未対応のCI build targetです: $target"

require_command arduino-cli
configure_arduino_env

build_dir="$M5_REPO_ROOT/.local/build/matrix/$(fqbn_slug "$target")"
log "ビルド: $target"
arduino_cli compile \
  --fqbn "$target" \
  --build-path "$build_dir" \
  --jobs 0 \
  --warnings all \
  "$M5_REPO_ROOT/ci/hello_m5"
