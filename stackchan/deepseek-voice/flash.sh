#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

allow_flash=false
replace_factory=false
for argument in "$@"; do
  case "$argument" in
    --allow-flash) allow_flash=true ;;
    --replace-factory-firmware) replace_factory=true ;;
    *) die "使用方法: $0 --allow-flash --replace-factory-firmware" ;;
  esac
done
[[ $allow_flash == true ]] || die "--allow-flash が必要です。"

require_command arduino-cli
load_local_env
require_model_config
verify_bound_device
resolved_port=$(require_port_access)
configure_arduino_env

[[ $BOARD_KEY == stackchan ]] || die "このファームはStackChan(CoreS3)専用です。現在の対象: $BOARD_MODEL"
[[ $replace_factory == true ]] ||
  die "StackChanの現行ファームを置換します。--replace-factory-firmware も指定してください。"

marker=$(backup_marker_path)
[[ -s $marker ]] ||
  die "検証済みの全Flashバックアップがありません。先に ./scripts/backup-flash.sh --allow-reset を実行してください。"

warn "StackChanを書き換えます。再起動後の不意な動作に備えて周囲を空けてください。"

# 実キー入りのsecrets.hを生成し、生成済みスケッチをコンパイルする（書込みなし）。
"$SCRIPT_DIR/build.sh"

build_source="$M5_REPO_ROOT/.local/generated/deepseek-voice/DeepSeekVoice"
build_dir="$M5_REPO_ROOT/.local/build/deepseek-voice"
[[ -f $build_source/deepseek_voice_secrets.h ]] || die "生成済みsecretsが見つかりません。"

log "StackChan DeepSeek音声版を書き込みます: $resolved_port"
arduino_cli compile \
  --fqbn m5stack:esp32:m5stack_cores3 \
  --build-path "$build_dir" \
  --warnings all \
  --upload \
  --port "$resolved_port" \
  "$build_source"
log "書込み完了: StackChan DeepSeek音声版"
