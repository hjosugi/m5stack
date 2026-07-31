#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

[[ ${1:-} == --allow-reset && $# == 1 ]] || die "使用方法: $0 --allow-reset"
require_command esptool
require_command dd
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
backup_partial="$backup_file.partial"
security_file="$backup_dir/security-info.txt"
metadata_file="$backup_dir/metadata.txt"
marker=$(backup_marker_path)
chunk_bytes=65536
chunk_count=$((BOARD_FLASH_BYTES / chunk_bytes))

((BOARD_FLASH_BYTES % chunk_bytes == 0)) || die "Flash容量を64 KiB単位へ安全に分割できません: $BOARD_FLASH_BYTES"

umask 077
mkdir -p "$backup_dir" "$(dirname -- "$marker")"

backup_complete=false
chunk_log="$backup_dir/chunk.log"
cleanup_incomplete_backup() {
  if [[ $backup_complete != true && $backup_dir == "$M5_REPO_ROOT/.local/backups/$BOARD_KEY/"* ]]; then
    rm -rf -- "$backup_dir"
  fi
}
trap cleanup_incomplete_backup EXIT

read_flash_piece() {
  local piece_offset=$1
  local piece_size=$2
  local piece_file=$3
  local piece_after_reset=$4
  local piece_label=$5
  local before_reset=$6
  local piece_attempt

  for ((piece_attempt = 1; piece_attempt <= 3; piece_attempt += 1)); do
    rm -f -- "$piece_file"
    if esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud "$M5_ESPTOOL_BAUD" \
      --before "$before_reset" --after "$piece_after_reset" read-flash "$piece_offset" "$piece_size" "$piece_file" --no-progress 2>&1 |
      redact_device_identity > "$chunk_log"; then
      rm -f -- "$chunk_log"
      return 0
    fi

    warn "$piece_label の読出しに失敗しました（試行 $piece_attempt/3）。"
    sed -n '1,120p' "$chunk_log" >&2
    before_reset=default-reset
  done

  rm -f -- "$piece_file" "$chunk_log"
  return 1
}

log "セキュリティ状態を読み取ります（本体をリセットします）。"
esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud "$M5_ESPTOOL_BAUD" \
  --before default-reset --after no-reset get-security-info 2>&1 |
  redact_device_identity |
  tee "$security_file"

if grep -Eiq 'secure boot[^[:alnum:]]*(enabled|true)|flash encryption[^[:alnum:]]*(enabled|true)' "$security_file"; then
  die "Secure BootまたはFlash Encryptionが有効です。暗号化済みバックアップを復旧可能と誤認しないため中止しました。"
fi

log "Flash全体 $BOARD_FLASH_BYTES bytes を64 KiBずつ読出します。"
: > "$backup_partial"
for ((chunk_index = 0; chunk_index < chunk_count; chunk_index += 1)); do
  chunk_offset=$((chunk_index * chunk_bytes))
  chunk_file="$backup_dir/chunk-$(printf '%03d' "$chunk_index").bin"
  after_reset=no-reset
  if ((chunk_index + 1 == chunk_count)); then
    after_reset=hard-reset
  fi

  if ((chunk_index % 16 == 0 || chunk_index + 1 == chunk_count)); then
    log "  チャンク $((chunk_index + 1))/$chunk_count: offset=$chunk_offset"
  fi

  chunk_label="チャンク $((chunk_index + 1))/$chunk_count"
  if ! read_flash_piece "$chunk_offset" "$chunk_bytes" "$chunk_file" "$after_reset" "$chunk_label" no-reset; then
    warn "$chunk_label を4 KiB単位へ分割して再試行します。"
    subpiece_bytes=4096
    subpiece_count=$((chunk_bytes / subpiece_bytes))
    subpiece_file="$backup_dir/subpiece.bin"
    : > "$chunk_file"

    for ((subpiece_index = 0; subpiece_index < subpiece_count; subpiece_index += 1)); do
      subpiece_offset=$((chunk_offset + subpiece_index * subpiece_bytes))
      subpiece_after_reset=no-reset
      if ((chunk_index + 1 == chunk_count && subpiece_index + 1 == subpiece_count)); then
        subpiece_after_reset=hard-reset
      fi
      subpiece_before_reset=no-reset
      if ((subpiece_index == 0)); then
        subpiece_before_reset=default-reset
      fi
      subpiece_label="$chunk_label サブチャンク $((subpiece_index + 1))/$subpiece_count"

      read_flash_piece "$subpiece_offset" "$subpiece_bytes" "$subpiece_file" "$subpiece_after_reset" "$subpiece_label" "$subpiece_before_reset" ||
        die "$subpiece_label を3回試行しても成功しませんでした。"
      subpiece_size=$(stat -c %s "$subpiece_file")
      [[ $subpiece_size == "$subpiece_bytes" ]] || die "サブチャンクサイズが一致しません: index=$subpiece_index size=$subpiece_size"
      dd if="$subpiece_file" of="$chunk_file" bs="$subpiece_bytes" seek="$subpiece_index" conv=notrunc status=none
      rm -f -- "$subpiece_file"
    done
  fi

  chunk_size=$(stat -c %s "$chunk_file")
  [[ $chunk_size == "$chunk_bytes" ]] || die "チャンクサイズが一致しません: index=$chunk_index size=$chunk_size"
  dd if="$chunk_file" of="$backup_partial" bs="$chunk_bytes" seek="$chunk_index" conv=notrunc status=none
  rm -f -- "$chunk_file"
done
mv -- "$backup_partial" "$backup_file"

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
  printf 'read_chunk_bytes=%s\n' "$chunk_bytes"
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

backup_complete=true
trap - EXIT

log "バックアップを検証しました: $backup_file"
log "識別子: sha256:$identifier（生のUSBシリアルは保存メタデータにも記録していません）"
warn "FlashイメージにはWi-Fi情報等が含まれ得ます。.local/外へコピーせず、公開しないでください。"
