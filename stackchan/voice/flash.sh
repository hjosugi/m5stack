#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

allow_flash=false
replace_factory=false
official_recovery_ready=false
interactive=false
for argument in "$@"; do
  case "$argument" in
    --allow-flash) allow_flash=true ;;
    --replace-factory-firmware) replace_factory=true ;;
    --official-recovery-ready) official_recovery_ready=true ;;
    --interactive | -i) interactive=true ;;
    *) die "使用方法: $0 --allow-flash --replace-factory-firmware [--official-recovery-ready] [--interactive]" ;;
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

# install-community-stackchan.sh と同じ方針: 全Flashバックアップが無い場合は、
# 公式M5Burnerで復旧できることを確認した時だけ --official-recovery-ready で進む。
marker=$(backup_marker_path)
if [[ ! -s $marker ]]; then
  [[ $official_recovery_ready == true ]] ||
    die "検証済み全Flashバックアップがありません。公式M5Burnerで復旧できることを確認した場合だけ --official-recovery-ready を追加してください。"
  warn "全Flashバックアップなしで進みます。公式M5BurnerとStackChan復旧手順を先に用意したことを確認してください。"
fi

warn "StackChanを書き換えます。再起動後の不意な動作に備えて周囲を空けてください。"

if [[ $interactive == true ]]; then
  printf '対象: %s (%s)  ポート: %s\n' "$BOARD_MODEL" "$M5_FQBN" "$resolved_port"
  printf '現行ファームを DeepSeek音声版 で上書きします（復旧はM5Burner工場版）。\n'
  read -r -p '書き込みますか？ [y/N] ' answer
  [[ $answer == y || $answer == Y ]] || die "中止しました。"
fi

# 実キー入りのsecrets.hを生成し、生成済みスケッチをコンパイルする（書込みなし）。
"$SCRIPT_DIR/build.sh"

build_source="$M5_REPO_ROOT/.local/generated/voice/DeepSeekVoice"
build_dir="$M5_REPO_ROOT/.local/build/voice"
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
