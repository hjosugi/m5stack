#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ ${1:-} == --allow-reset && $# == 1 ]] || die "使用方法: $0 --allow-reset"
require_command esptool
load_local_env
require_model_config
verify_bound_device
resolved_port=$(require_port_access)

if [[ $BOARD_KEY == stackchan ]]; then
  warn "StackChanをリセットします。周囲を空け、頭部・台座・ケーブルにサーボ可動の余裕があることを確認してください。"
fi

identifier=$(device_hash)
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_dir="$M5_REPO_ROOT/.local/backups/$BOARD_KEY/$timestamp"
backup_file="$backup_dir/flash-${BOARD_FLASH_BYTES}.bin"
security_file="$backup_dir/security-info.txt"
metadata_file="$backup_dir/metadata.txt"
marker=$(backup_marker_path)

umask 077
mkdir -p "$backup_dir" "$(dirname -- "$marker")"

log "セキュリティ状態を読み取ります（本体をリセットします）。"
esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud 460800 \
  --before default-reset --after no-reset get-security-info | tee "$security_file"

if grep -Eiq 'secure boot[^[:alnum:]]*(enabled|true)|flash encryption[^[:alnum:]]*(enabled|true)' "$security_file"; then
  die "Secure BootまたはFlash Encryptionが有効です。暗号化済みバックアップを復旧可能と誤認しないため中止しました。"
fi

log "Flash全体 $BOARD_FLASH_BYTES bytes を読出します。"
esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud 460800 \
  --before no-reset --after hard-reset read-flash 0 "$BOARD_FLASH_BYTES" "$backup_file" --no-progress

actual_size=$(stat -c %s "$backup_file")
[[ $actual_size == "$BOARD_FLASH_BYTES" ]] || die "バックアップサイズが一致しません: $actual_size"
sha256sum "$backup_file" > "$backup_file.sha256"

{
  printf 'format=1\n'
  printf 'created_utc=%s\n' "$timestamp"
  printf 'model=%s\n' "$M5_MODEL"
  printf 'board_key=%s\n' "$BOARD_KEY"
  printf 'chip=%s\n' "$BOARD_CHIP"
  printf 'flash_bytes=%s\n' "$BOARD_FLASH_BYTES"
  printf 'usb_id=%s:%s\n' "${M5_USB_VID,,}" "${M5_USB_PID,,}"
  printf 'device_identifier_sha256_12=%s\n' "$identifier"
  printf 'source_repository_commit=%s\n' "$(git -C "$M5_REPO_ROOT" rev-parse HEAD)"
  printf 'flash_sha256=%s\n' "$(cut -d ' ' -f 1 "$backup_file.sha256")"
} > "$metadata_file"

{
  printf 'backup=%s\n' "$backup_file"
  printf 'sha256=%s\n' "$(cut -d ' ' -f 1 "$backup_file.sha256")"
  printf 'created_utc=%s\n' "$timestamp"
} > "$marker"

log "バックアップを検証しました: $backup_file"
log "識別子: sha256:$identifier（生のUSBシリアルは保存メタデータにも記録していません）"
warn "FlashイメージにはWi-Fi情報等が含まれ得ます。.local/外へコピーせず、公開しないでください。"
