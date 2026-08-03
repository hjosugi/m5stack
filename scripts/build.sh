#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command arduino-cli
load_local_env
require_model_config
configure_arduino_env

build_dir="$M5_REPO_ROOT/.local/build/arduino/$(fqbn_slug "$M5_FQBN")"
log "$M5_MODEL ($M5_FQBN) 向けに安全確認用スケッチをビルドします。"
arduino_cli compile \
  --fqbn "$M5_FQBN" \
  --build-path "$build_dir" \
  --warnings all \
  "$M5_REPO_ROOT/ci/hello_m5"
log "ビルド完了: $build_dir"
log "実機への書込みは行っていません。"
