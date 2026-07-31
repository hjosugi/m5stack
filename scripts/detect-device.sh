#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

load_local_env
detect_m5_usb

identifier=未提供
if [[ -n $DETECTED_SERIAL ]]; then
  identifier="sha256:$(hash_identifier "$DETECTED_SERIAL")"
fi

port_display=未検出
if [[ -n $DETECTED_PORT ]]; then
  resolved_port=$(readlink -f -- "$DETECTED_PORT")
  port_display=$resolved_port
  if [[ $DETECTED_PORT == "$M5_BY_ID_ROOT"/* ]]; then
    port_display="$resolved_port（by-id固定済み・実名非表示）"
  fi
fi

log "M5/ESP32 USBデバイスを1台検出しました。"
log "  製造元: ${DETECTED_MANUFACTURER:-不明}"
log "  USB製品名: ${DETECTED_PRODUCT:-不明}"
log "  USB ID: ${DETECTED_VID,,}:${DETECTED_PID,,}"
log "  識別子: $identifier（生のシリアルは非表示）"
log "  ポート: $port_display"
log "  sysfs: $DETECTED_SYSFS_KEY"

if [[ -n $DETECTED_PORT && -e $DETECTED_PORT ]]; then
  if [[ -r $DETECTED_PORT && -w $DETECTED_PORT ]]; then
    log "  アクセス: 読み書き可能"
  else
    warn "ポートへアクセスできません。必要時だけ ./scripts/grant-port-access.sh を実行してください。"
  fi
else
  warn "USBシリアル用のデバイスノードが見つかりません。"
fi

if [[ ${DETECTED_VID,,}:${DETECTED_PID,,} == 303a:1001 ]]; then
  log "判定: EspressifネイティブUSBです。USB IDだけではM5製品型番を確定できません。"
fi
log "安全確認: シリアルポートは開いておらず、リセット・読出し・書込みは行っていません。"
