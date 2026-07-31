#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ ${1:-} == --allow-flash && $# == 2 ]] || die "使用方法: $0 --allow-flash <.local/backups内のflash.bin>"
require_command esptool
require_command realpath
load_local_env
require_model_config
verify_bound_device
resolved_port=$(require_port_access)

backup_root=$(realpath -m -- "$M5_REPO_ROOT/.local/backups")
backup_file=$(realpath -e -- "$2")
[[ $backup_file == "$backup_root"/* ]] || die "復旧元は $backup_root 内の検証済みバックアップに限定しています。"
[[ -f $backup_file.sha256 ]] || die "SHA-256ファイルがありません: $backup_file.sha256"

expected_hash=$(cut -d ' ' -f 1 "$backup_file.sha256")
actual_hash=$(sha256sum "$backup_file" | cut -d ' ' -f 1)
[[ $actual_hash == "$expected_hash" ]] || die "バックアップのSHA-256が一致しません。"
actual_size=$(stat -c %s "$backup_file")
[[ $actual_size == "$BOARD_FLASH_BYTES" ]] || die "バックアップサイズが対象製品と一致しません。"

warn "$M5_MODEL のFlash全体を検証済みバックアップで上書きします。電源とUSBを抜かないでください。"
if [[ $BOARD_KEY == stackchan ]]; then
  warn "再起動後のサーボ動作に備えて周囲を空けてください。"
fi
esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud 460800 \
  --before default-reset --after hard-reset write-flash 0 "$backup_file"
log "全Flashの復旧が完了しました。"
