#!/usr/bin/env bash
set -euo pipefail

# いまPCが使用中のWi-Fi（SSID/パスワード）を、DeepSeek音声版の.envへ取り込む。
# 既定は対話確認あり。--yes で無確認、--ssid=NAME で対象SSIDを上書き。
# ESP32-S3は2.4GHz専用のため、対象SSIDに2.4GHzの電波が無ければ警告する。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command nmcli

assume_yes=false
target_ssid=''
target_env=''
for argument in "$@"; do
  case "$argument" in
    --yes | -y) assume_yes=true ;;
    --ssid=*) target_ssid=${argument#--ssid=} ;;
    --env=*) target_env=${argument#--env=} ;;
    *) die "使用方法: $0 [--yes] [--ssid=NAME] [--env=PATH]" ;;
  esac
done

env_file=${target_env:-"$M5_REPO_ROOT/stackchan/voice/.env"}
[[ -f $env_file ]] || die "$env_file がありません。.env.exampleをコピーしてください。"

conn=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 ~ /wireless/ {print $1; exit}')
[[ -n $conn ]] || die "アクティブなWi-Fi接続が見つかりません。"

ssid=$target_ssid
if [[ -z $ssid ]]; then
  ssid=$(nmcli -t -f 802-11-wireless.ssid connection show "$conn" | cut -d: -f2-)
fi
[[ -n $ssid ]] || die "SSIDを取得できません。"

has_24=no
# terseモードで "SSID:FREQ" を得る。FREQは "2462 MHz" 形式なので先頭の数値で判定する。
if nmcli -t -f SSID,FREQ dev wifi list |
  awk -F: -v s="$ssid" '$1 == s && $2 ~ /^2[0-9]{3}/ {found = 1} END {exit !found}'; then
  has_24=yes
fi
[[ $has_24 == yes ]] ||
  warn "SSID '$ssid' に2.4GHzの電波が見当たりません。ESP32-S3は5GHzに繋がりません。"

psk=$(nmcli -s -g 802-11-wireless-security.psk connection show "$conn")
[[ -n $psk ]] || die "パスワード(PSK)を取得できません（sudoが必要な場合があります）。"

log "検出したWi-Fi: SSID=$ssid  2.4GHz=$has_24  （パスワードは表示しません）"
if [[ $assume_yes != true ]]; then
  read -r -p "この設定を $env_file に書き込みますか？ [y/N] " answer
  [[ $answer == y || $answer == Y ]] || die "中止しました。"
fi

# WIFI_SSID / WIFI_PASSWORD を置換（他キーは保持、PSKは表示しない）。
umask 077
temp_file=$(mktemp "${env_file}.tmp.XXXXXX")
{
  grep -vE '^(WIFI_SSID|WIFI_PASSWORD)=' "$env_file"
  printf 'WIFI_SSID=%s\n' "$ssid"
  printf 'WIFI_PASSWORD=%s\n' "$psk"
} > "$temp_file"
chmod 600 "$temp_file"
mv -f -- "$temp_file" "$env_file"
log "書き込み完了: $env_file の WIFI_SSID / WIFI_PASSWORD を更新しました。"
