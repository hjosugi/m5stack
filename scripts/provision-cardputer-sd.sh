#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# M5Launcherが公開するSD(MSC)をFAT32へ初期化し、取得済みFW binを配置する。
# M5LauncherはSDのFAT側しか読めないため、exFAT/他FSのカードはFAT32へ作り直す。
#
# 安全策:
#   - 対象は udev の ID_MODEL=Launcher_SD かつ ID_VENDOR_ID=303a かつ USB のブロック
#     デバイスに限定し、1台に確定できないと中止（システムディスク誤爆の防止）。
#   - / や /boot を含むディスクは対象外。
#   - 破壊操作には --allow-format が必須。
#
# 使用方法:
#   provision-cardputer-sd.sh                 安全案内のみ（何もしない）
#   provision-cardputer-sd.sh --allow-format  SDをFAT32初期化しbinを配置（pkexec認証）

CACHE_DIR="$M5_CARDPUTER_FW_CACHE"

allow_format=false
for argument in "$@"; do
  case "$argument" in
    --allow-format) allow_format=true ;;
    *) die "使用方法: $0 [--allow-format]" ;;
  esac
done

# 直挿しカードリーダー等を明示指定する場合（SD_DEVICE=/dev/sdX）。
# Launcher の USB-MSC ブリッジ経由の書込みは低速で不安定なため、通常はこちらを使う。
direct_device=${SD_DEVICE:-}

# 明示指定デバイスを厳格に検証する（USB・リムーバブル・ディスク全体・非システム）。
resolve_direct_device() {
  local dev=$1 typ tran rm
  [[ $dev == /dev/sd[a-z] ]] || die "SD_DEVICE は /dev/sdX（ディスク全体）で指定してください: $dev"
  [[ -b $dev ]] || die "ブロックデバイスがありません: $dev"
  typ=$(lsblk -ndo TYPE "$dev" 2> /dev/null)
  [[ $typ == disk ]] || die "$dev はディスク全体ではありません（type=$typ）。"
  tran=$(lsblk -ndo TRAN "$dev" 2> /dev/null)
  [[ $tran == usb ]] || die "$dev はUSB接続ではありません（tran=$tran）。誤爆防止のため中止。"
  rm=$(lsblk -ndo RM "$dev" 2> /dev/null)
  [[ $rm == 1 ]] || die "$dev はリムーバブル(RM=1)ではありません。中止。"
  SD_DEV=$dev
}

# 直挿しカードリーダー内のSDを自動特定する。
# 条件: USB・リムーバブル・容量 4GB〜512GB。ただし Cardputer の USB-MSC ブリッジ
# (303a / Launcher_SD) は除外する（ブリッジ経由の書込みは低速で不安定なため）。
# sd名は挿抜で入れ替わるため、名前ではなく属性で選ぶ。
find_reader_sd() {
  local block name props sz
  local -a matches=()
  shopt -s nullglob
  for block in /sys/block/sd*; do
    name=$(basename "$block")
    sz=$(($(cat "$block/size" 2> /dev/null || echo 0) * 512))
    ((sz >= 4000000000 && sz <= 512000000000)) || continue
    props=$(udevadm info --query=property --name="/dev/$name" 2> /dev/null || true)
    grep -q '^ID_BUS=usb$' <<< "$props" || grep -q '^ID_USB_DRIVER=' <<< "$props" || continue
    [[ $(cat "$block/removable" 2> /dev/null) == 1 ]] || continue
    # Cardputer の Launcher SD ブリッジは除外（実カードのリーダーだけを対象に）。
    if grep -q '^ID_MODEL=Launcher_SD$' <<< "$props" || grep -q '^ID_VENDOR_ID=303a$' <<< "$props"; then
      continue
    fi
    matches+=("/dev/$name")
  done
  shopt -u nullglob
  ((${#matches[@]} > 0)) || die "リーダー内のSDが見つかりません。SDをカードリーダーに直挿ししてください（Cardputerのブリッジは対象外）。"
  ((${#matches[@]} == 1)) || die "対象SD候補が${#matches[@]}台あります(${matches[*]})。1枚だけにするか SD_DEVICE=/dev/sdX で明示してください。"
  SD_DEV=${matches[0]}
}

# 対象ディスクが / や /boot を含んでいないことを確認する（多重の誤爆防止）。
assert_not_system_disk() {
  local dev=$1 root_src part mnt
  root_src=$(findmnt -no SOURCE / 2> /dev/null || true)
  while read -r part mnt; do
    [[ -z $part ]] && continue
    if [[ $mnt == / || $mnt == /boot || $mnt == /boot/* || $mnt == /home ]]; then
      die "対象 $dev にシステム領域($mnt)が含まれます。中止しました。"
    fi
  done < <(lsblk -nro PATH,MOUNTPOINT "$dev" 2> /dev/null)
  if [[ -n $root_src && $root_src == "$dev"* ]]; then
    die "対象 $dev はルートFSのディスクです。中止しました。"
  fi
}

if [[ -n $direct_device ]]; then
  resolve_direct_device "$direct_device"
else
  find_reader_sd
fi
size_bytes=$(($(cat "/sys/block/$(basename "$SD_DEV")/size") * 512))
size_gb=$((size_bytes / 1000 / 1000 / 1000))
((size_bytes >= 1000000000 && size_bytes <= 2200000000000)) || die "$SD_DEV のサイズが想定外です（${size_gb}GB）。誤爆防止のため中止。"
assert_not_system_disk "$SD_DEV"
sd_desc=$(lsblk -ndo TRAN,RM,MODEL "$SD_DEV" 2> /dev/null | tr -s ' ')

if [[ $allow_format != true ]]; then
  cat << GUIDE
Cardputer SD 初期化ガイド（安全案内のみ・実行はしません）

対象デバイス: $SD_DEV （約 ${size_gb} GB, $sd_desc）
これは何:     SDを単一FAT32へ初期化し、取得済みFW binを配置する。
警告:         SD上の既存データは全消去されます。
前提:         task cardputer:fw:fetch でbinを取得済みであること。

実行:         task cardputer:sd:provision:run   （pkexec認証が出ます）
GUIDE
  exit 0
fi

require_command pkexec
require_command udisksctl
require_command findmnt

shopt -s nullglob
bins=("$CACHE_DIR"/*.bin)
shopt -u nullglob
((${#bins[@]} > 0)) || die "配置するbinがありません。先に task cardputer:fw:fetch を実行してください。"

warn "$SD_DEV （約 ${size_gb} GB）をFAT32へ初期化します。既存データは全消去されます。"

# 既存マウントを解除（自動マウント対策）。
shopt -s nullglob
for part in "$SD_DEV"?*; do
  udisksctl unmount -b "$part" > /dev/null 2>&1 || true
done
shopt -u nullglob

log "パーティション作成とFAT32フォーマットを行います（pkexec認証）。"
# shellcheck disable=SC2016  # $1 は pkexec 先の sh で展開させる。
pkexec sh -c '
  set -e
  dev="$1"
  case "$dev" in
    /dev/sd[a-z]) ;;
    *) echo "想定外のデバイス: $dev" >&2; exit 1 ;;
  esac
  # 認証中に自動再マウントされていても、特権側で確実に解除してから初期化する
  # （pre-pkexec の unmount と wipefs の間の再マウント競合=busy を防ぐ）。
  for p in "$dev"?*; do
    [ -b "$p" ] || continue
    umount "$p" 2>/dev/null || umount -l "$p" 2>/dev/null || true
  done
  wipefs -a "$dev"
  parted -s "$dev" mklabel msdos
  parted -s "$dev" mkpart primary fat32 1MiB 100%
  partprobe "$dev" 2>/dev/null || true
  udevadm settle || true
  # パーティションデバイスが現れるまで少し待つ
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -b "${dev}1" ] && break; sleep 0.3; done
  mkfs.vfat -F 32 -s 64 -n CARDPUTER "${dev}1"
' sh "$SD_DEV"

udevadm settle 2> /dev/null || true
part="${SD_DEV}1"
[[ -b $part ]] || die "初期化後のパーティションが見つかりません: $part"

log "SDをマウントしてbinを配置します。"
udisksctl mount -b "$part" > /dev/null
mp=$(lsblk -no MOUNTPOINT "$part" | tr -d ' ')
[[ -n $mp && -d $mp ]] || die "マウント先を取得できませんでした。"

copied=0
{
  printf 'Cardputer firmware collection (M5Launcherで選択して書込み)\n'
  printf 'generated_by=provision-cardputer-sd.sh\n\n'
  printf '%-26s %-10s %s\n' NAME VERSION FILE
} > "$mp/FIRMWARE_INDEX.txt"

while IFS=$'\t' read -r key name version offset filename sha url; do
  [[ -z $key || $key == \#* ]] && continue
  src="$CACHE_DIR/$filename"
  [[ -f $src ]] || continue
  cp -- "$src" "$mp/$filename"
  printf '%-26s %-10s %s\n' "$name" "$version" "$filename" >> "$mp/FIRMWARE_INDEX.txt"
  copied=$((copied + 1))
done < "$M5_CARDPUTER_FW_CATALOG"

sync
udisksctl unmount -b "$part" > /dev/null || true

log "完了: $copied 個のFW binを $SD_DEV (FAT32) へ配置しました。"
log "SDをCardputerに戻し、M5LauncherのSDメニューから選んで書込めます。"
