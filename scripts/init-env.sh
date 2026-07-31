#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC2034

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

force=false
if [[ ${1:-} == --force ]]; then
  force=true
elif (($# > 0)); then
  die "使用方法: $0 [--force]"
fi

if [[ -e $M5_ENV_FILE && $force != true ]]; then
  die "$M5_ENV_FILE は既にあります。再検出する場合は --force を指定してください。"
fi

M5_USB_SERIAL=
detect_m5_usb
[[ -n $DETECTED_SERIAL ]] || die "安全に対象を固定できるUSBシリアルがありません。"
[[ -n $DETECTED_PORT ]] || die "シリアルポートが見つかりません。"

M5_MODEL=
M5_FQBN=
M5_PORT=$DETECTED_PORT
M5_USB_SERIAL=$DETECTED_SERIAL
M5_USB_VID=${DETECTED_VID,,}
M5_USB_PID=${DETECTED_PID,,}
write_local_env

log "$M5_ENV_FILE を権限600で作成しました。"
log "対象識別子: sha256:$(hash_identifier "$M5_USB_SERIAL")（生のシリアルは非表示）"
log "次に本体印字を確認し、./scripts/select-board.sh list を実行してください。"
