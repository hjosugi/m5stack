#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# M5/ESP32 USB-シリアルへの永続アクセス用 udev ルールを配置する。
# 一時ACL(grant-port-access.sh)と違い、以後は挿すたびに自動でアクセス権が付く。
#
# 使用方法:
#   install-udev-rule.sh              安全案内のみ（何もしない）
#   install-udev-rule.sh --install    /etc/udev/rules.d/ へ配置し udev を再読込（pkexec）

RULE_SRC="$M5_REPO_ROOT/config/udev/99-m5stack-serial.rules"
RULE_DEST="/etc/udev/rules.d/99-m5stack-serial.rules"

if [[ ${1:-} != --install ]]; then
  cat << GUIDE
udev 永続ルール導入ガイド（安全案内のみ・実行はしません）

これは何: ログイン中のユーザへ M5/ESP32 シリアルのアクセス権(ACL)を自動付与。
         以後 task grant は不要になります（USB抜き差しでも維持）。
ルール:   $RULE_SRC
配置先:   $RULE_DEST

実行:     task device:grant:persist:run   （pkexec認証が出ます）
確認後:   一度USBを抜き差し → task cardputer:fw:flash:run FW=... 等がそのまま通る

解除:     sudo rm $RULE_DEST && sudo udevadm control --reload-rules && sudo udevadm trigger
GUIDE
  exit 0
fi

require_command pkexec
[[ -f $RULE_SRC ]] || die "ルールファイルがありません: $RULE_SRC"

log "udev ルールを $RULE_DEST へ配置し、udev を再読込します（pkexec認証）。"
# shellcheck disable=SC2016  # $1/$2 は pkexec 先の sh で展開させるため単一引用符が正しい。
pkexec sh -c '
  set -e
  install -m 0644 -o root -g root -- "$1" "$2"
  udevadm control --reload-rules
  udevadm trigger --subsystem-match=tty
' sh "$RULE_SRC" "$RULE_DEST"

log "配置しました: $RULE_DEST"
log "一度USBを抜き差しすると、以後は自動でアクセス権が付きます（task grant 不要）。"
