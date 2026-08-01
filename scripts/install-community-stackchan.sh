#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

allow_flash=false
replace_factory=false
official_recovery_ready=false
for argument in "$@"; do
  case "$argument" in
    --allow-flash) allow_flash=true ;;
    --replace-factory-firmware) replace_factory=true ;;
    --official-recovery-ready) official_recovery_ready=true ;;
    *)
      die "使用方法: $0 --allow-flash --replace-factory-firmware [--official-recovery-ready]"
      ;;
  esac
done

[[ $allow_flash == true ]] || die "--allow-flash が必要です。"
[[ $replace_factory == true ]] || die "--replace-factory-firmware が必要です。"

require_command curl
require_command esptool
require_command grep
require_command sha256sum
require_command unzip
load_local_env
require_model_config
[[ $BOARD_KEY == stackchan ]] || die "このスクリプトはM5StackChan（K151）専用です。"
verify_bound_device
resolved_port=$(require_port_access)
[[ $STACKCHAN_COMMUNITY_VERSION =~ ^[0-9A-Za-z._-]+$ ]] || die "コミュニティ版の固定versionが不正です。"

marker=$(backup_marker_path)
if [[ ! -s $marker ]]; then
  [[ $official_recovery_ready == true ]] ||
    die "検証済み全Flashバックアップがありません。公式M5Burnerで復旧できることを確認した場合だけ --official-recovery-ready を追加してください。"
  warn "全Flashバックアップなしで進みます。公式M5BurnerとStackChan復旧手順を先に用意したことを確認してください。"
fi

release_dir="$M5_REPO_ROOT/.local/firmware/stack-chan-v$STACKCHAN_COMMUNITY_VERSION"
archive="$release_dir/stack-chan-firmware-v$STACKCHAN_COMMUNITY_VERSION.zip"
archive_partial="$archive.partial"
target_dir="$release_dir/tech.moddable.stackchan/m5stackchan_cores3"
bootloader="$target_dir/bootloader.bin"
partition_table="$target_dir/partition-table.bin"
application="$target_dir/xs_esp32.bin"

umask 077
mkdir -p "$release_dir"
if [[ ! -f $archive ]]; then
  rm -f -- "$archive_partial"
  trap 'rm -f -- "$archive_partial"' EXIT
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$archive_partial" "$STACKCHAN_COMMUNITY_URL"
  printf '%s  %s\n' "$STACKCHAN_COMMUNITY_SHA256" "$archive_partial" | sha256sum --check -
  mv -- "$archive_partial" "$archive"
  trap - EXIT
else
  printf '%s  %s\n' "$STACKCHAN_COMMUNITY_SHA256" "$archive" | sha256sum --check -
fi

unzip -oq "$archive" 'tech.moddable.stackchan/m5stackchan_cores3/*' -d "$release_dir"
[[ -s $bootloader && -s $partition_table && -s $application ]] || die "K151用配布イメージが不足しています。"
bootloader_info=$(esptool image-info "$bootloader")
application_info=$(esptool image-info "$application")
grep -Fq 'Detected image type: ESP32-S3' <<< "$bootloader_info" || die "bootloaderはESP32-S3用ではありません。"
grep -Fq 'Flash size: 16MB' <<< "$bootloader_info" || die "bootloaderのFlash容量指定が16 MBではありません。"
grep -Fq 'Flash mode: DIO' <<< "$bootloader_info" || die "bootloaderのFlash modeがDIOではありません。"
grep -Fq 'Detected image type: ESP32-S3' <<< "$application_info" || die "applicationはESP32-S3用ではありません。"
grep -Fq 'Flash size: 16MB' <<< "$application_info" || die "applicationのFlash容量指定が16 MBではありません。"
grep -Fq 'Flash mode: DIO' <<< "$application_info" || die "applicationのFlash modeがDIOではありません。"

security_file=$(mktemp "$release_dir/security-info.XXXXXX")
trap 'rm -f -- "$security_file"' EXIT
log "セキュリティ状態を確認します（本体をリセットします）。"
esptool --chip esp32s3 --port "$resolved_port" --baud "$M5_ESPTOOL_BAUD" \
  --before default-reset --after no-reset get-security-info 2>&1 |
  redact_device_identity |
  tee "$security_file"
if grep -Eiq 'secure boot[^[:alnum:]]*(enabled|true)|flash encryption[^[:alnum:]]*(enabled|true)' "$security_file"; then
  die "Secure BootまたはFlash Encryptionが有効なため中止しました。eFuseは変更しないでください。"
fi
rm -f -- "$security_file"
trap - EXIT

warn "StackChanの工場ファームウェアをコミュニティ版v$STACKCHAN_COMMUNITY_VERSIONへ置換します。"
warn "再起動後にサーボが動きます。頭部、台座、USBケーブルから手を離してください。"
esptool --chip esp32s3 --port "$resolved_port" --baud "$M5_ESPTOOL_BAUD" \
  --before no-reset --after hard-reset write-flash \
  --flash-mode dio --flash-freq 80m --flash-size 16MB \
  0x0 "$bootloader" \
  0x8000 "$partition_table" \
  0x10000 "$application" 2>&1 |
  redact_device_identity

log "Stack-chanコミュニティ版v$STACKCHAN_COMMUNITY_VERSIONを書き込み、Flashハッシュを検証しました。"
log "Wi-Fi未設定の場合は https://stack-chan.github.io/stack-chan/web/preference/ からBLE設定してください。"
