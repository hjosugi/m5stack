#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

allow_flash=false
replace_factory=false
for argument in "$@"; do
  case "$argument" in
    --allow-flash) allow_flash=true ;;
    --replace-factory-firmware) replace_factory=true ;;
    *) die "使用方法: $0 --allow-flash [--replace-factory-firmware]" ;;
  esac
done
[[ $allow_flash == true ]] || die "--allow-flash が必要です。"

require_command arduino-cli
load_local_env
require_model_config
verify_bound_device
require_port_access > /dev/null
configure_arduino_env

marker=$(backup_marker_path)
[[ -s $marker ]] || die "検証済みの全Flashバックアップがありません。先に ./scripts/backup-flash.sh --allow-reset を実行してください。"

if [[ $BOARD_KEY == stackchan && $replace_factory != true ]]; then
  die "StackChanの工場ファームウェアを置換するには --replace-factory-firmware も必要です。OTA機能等は失われます。"
fi

if [[ $BOARD_KEY == stackchan ]]; then
  warn "StackChanを書き換えます。再起動後の不意な動作に備えて周囲を空けてください。"
fi

build_dir="$M5_REPO_ROOT/.local/build/arduino/$(fqbn_slug "$M5_FQBN")"
arduino_cli compile \
  --fqbn "$M5_FQBN" \
  --build-path "$build_dir" \
  --warnings all \
  --upload \
  --port "$M5_PORT" \
  "$M5_REPO_ROOT/ci/hello_m5"
log "書込み完了: $M5_MODEL"
