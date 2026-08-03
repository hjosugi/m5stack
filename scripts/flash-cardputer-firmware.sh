#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Cardputer / Cardputer-Adv へ、固定版のコミュニティFW(bin)を 0x0 書込みする。
# 既存の安全機構を再利用する:
#   - .env の機器バインド（verify_bound_device）で対象を1台に固定
#   - 全Flashバックアップmarker（backup-flash.sh）が無ければ拒否
#   - ポートの一時ACL（grant-port-access.sh）が無ければ拒否
#   - Secure Boot / Flash Encryption が有効なら拒否
#   - bin の sha256 をカタログ固定値と照合
#
# 使用方法:
#   flash-cardputer-firmware.sh                       安全案内を表示（何もしない）
#   flash-cardputer-firmware.sh --allow-flash <key>   実行（key: launcher/bruce/gamestation…）

CATALOG="$M5_REPO_ROOT/config/cardputer-firmware.tsv"
CACHE_DIR="$M5_REPO_ROOT/.local/firmware-cache/cardputer"

allow_flash=false
firmware_key=""
for argument in "$@"; do
  case "$argument" in
    --allow-flash) allow_flash=true ;;
    -*) die "使用方法: $0 --allow-flash <key>" ;;
    *)
      [[ -z $firmware_key ]] || die "FWキーは1つだけ指定してください。"
      firmware_key=$argument
      ;;
  esac
done

if [[ $allow_flash != true ]]; then
  cat << 'GUIDE'
Cardputer コミュニティFW 書込みガイド（安全案内のみ・実行はしません）

手順:
  1. 対象を切替:      task target:cardputer                     （.env.cardputer をアクティブ化）
  2. ポート権限:      task device:grant                         （pkexecで一時ACL・要ユーザ操作）
  3. 全Flashバックアップ: task device:backup:run                （復旧用。markerが必須）
  4. binを取得:       task cardputer:fw:fetch                   （固定版をsha検証で取得）
  5. 書込み:          task cardputer:fw:flash:run FW=launcher   （0x0へ書込み）

  （初回のみ・プロファイル未作成なら: ./scripts/init-env.sh --force → task device:select MODEL=cardputer-adv）

推奨構成: まず launcher を書込み → M5Launcherから Bruce 等をSD/OTAで導入。
カタログ一覧: task cardputer:fw:list
GUIDE
  exit 0
fi

[[ -n $firmware_key ]] || die "FWキーを指定してください（例: --allow-flash launcher）。"
[[ -f $CATALOG ]] || die "カタログが見つかりません: $CATALOG"

# カタログから該当行を取得。
cat_name="" cat_version="" cat_offset="" cat_filename="" cat_sha=""
# shellcheck disable=SC2034  # url列は書込みでは使わない（fetch側で使用）。
while IFS=$'\t' read -r key name version offset filename sha url; do
  [[ -z $key || $key == \#* ]] && continue
  if [[ $key == "$firmware_key" ]]; then
    cat_name=$name cat_version=$version cat_offset=$offset cat_filename=$filename cat_sha=$sha
    break
  fi
done < "$CATALOG"
[[ -n $cat_filename ]] || die "不明なFWキーです: $firmware_key（task cardputer:fw:list で確認）。"
[[ $cat_offset == 0x0 ]] || die "このスクリプトは 0x0 全体イメージ専用です（offset=$cat_offset）。"

require_command esptool
require_command sha256sum
load_local_env
require_model_config
verify_bound_device

# Cardputer以外へ焼かないためのガード（StackChan等への誤爆防止）。
[[ $BOARD_KEY == cardputer || $BOARD_KEY == cardputer-adv ]] ||
  die "現在の対象は $BOARD_KEY です。task device:select MODEL=cardputer-adv 等でCardputerへ切替えてください。"

resolved_port=$(require_port_access)

marker=$(backup_marker_path)
[[ -s $marker ]] || die "検証済みの全Flashバックアップがありません。先に task device:backup:run を実行してください。"

bin_path="$CACHE_DIR/$cat_filename"
[[ -f $bin_path ]] || die "binがありません: $bin_path（先に task cardputer:fw:fetch）。"
printf '%s  %s\n' "$cat_sha" "$bin_path" | sha256sum -c --status ||
  die "binのsha256が固定値と一致しません。task cardputer:fw:fetch $firmware_key で取り直してください。"

# 暗号化状態を確認（暗号化領域へ平文を書いて壊さないため）。
security_info=$(esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud "$M5_ESPTOOL_BAUD" \
  --before default-reset --after no-reset get-security-info 2>&1 | redact_device_identity || true)
if printf '%s' "$security_info" | grep -Eiq 'secure boot[^[:alnum:]]*(enabled|true)|flash encryption[^[:alnum:]]*(enabled|true)'; then
  die "Secure BootまたはFlash Encryptionが有効です。平文binの書込みを中止しました。"
fi

warn "$BOARD_MODEL へ $cat_name $cat_version を 0x0 へ書込みます。既存アプリは置き換わります。"
warn "復旧が必要になったら task device:restore（バックアップ）または M5Burner を使用してください。"

esptool --chip "$BOARD_CHIP" --port "$resolved_port" --baud "$M5_ESPTOOL_BAUD" \
  --before default-reset --after hard-reset \
  write-flash --flash-size keep "$cat_offset" "$bin_path"

log "書込み完了: $cat_name $cat_version -> $BOARD_MODEL"
log "本体が再起動します。M5Launcherの場合はSD/OTAから次のFWを導入できます。"
