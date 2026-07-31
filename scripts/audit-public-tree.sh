#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if rg --hidden --glob '!.git/**' --glob '!.local/**' --glob '!.env' \
  '^[[:blank:]]*M5_USB_SERIAL=[A-Za-z0-9]' "$M5_REPO_ROOT" > /dev/null; then
  die "公開対象ツリーにUSBシリアルらしき値があります。"
fi

if [[ -f $M5_ENV_FILE ]]; then
  load_local_env
  if [[ -n ${M5_USB_SERIAL:-} ]] && rg -l -F --hidden \
    --glob '!.git/**' --glob '!.local/**' --glob '!.env' \
    -- "$M5_USB_SERIAL" "$M5_REPO_ROOT" > /dev/null; then
    die "公開対象ツリーに接続実機の生USBシリアルがあります。"
  fi
fi

log "公開対象に実機USBシリアルが含まれないことを確認しました。"
