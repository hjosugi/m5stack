#!/usr/bin/env bash
set -euo pipefail

# このPCのLAN IPを、DeepSeek音声版の LOCAL_HOST として取り込む。
# 既定は対話確認あり。--yes で無確認、--iface=IFACE でインターフェース上書き。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command ip

assume_yes=false
iface=''
target_env=''
for argument in "$@"; do
  case "$argument" in
    --yes | -y) assume_yes=true ;;
    --iface=*) iface=${argument#--iface=} ;;
    --env=*) target_env=${argument#--env=} ;;
    *) die "使用方法: $0 [--yes] [--iface=IFACE] [--env=PATH]" ;;
  esac
done

env_file=${target_env:-"$M5_REPO_ROOT/stackchan/voice/.env"}
[[ -f $env_file ]] || die "$env_file がありません。.env.exampleをコピーしてください。"

if [[ -z $iface ]]; then
  iface=$(ip -o -4 route show to default 2> /dev/null | awk '{print $5; exit}')
fi
[[ -n $iface ]] || die "既定ルートのインターフェースが分かりません。--iface で指定してください。"

lan_ip=$(ip -4 -o addr show "$iface" 2> /dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
[[ -n $lan_ip ]] || die "$iface のIPv4が取得できません。"

log "PCのIP: $lan_ip (iface=$iface) を LOCAL_HOST に設定します。"
if [[ $assume_yes != true ]]; then
  read -r -p "$env_file を更新しますか？ [y/N] " answer
  [[ $answer == y || $answer == Y ]] || die "中止しました。"
fi

umask 077
temp_file=$(mktemp "${env_file}.tmp.XXXXXX")
{
  grep -vE '^LOCAL_HOST=' "$env_file"
  printf 'LOCAL_HOST=%s\n' "$lan_ip"
} > "$temp_file"
chmod 600 "$temp_file"
mv -f -- "$temp_file" "$env_file"
log "書き込み完了: LOCAL_HOST=$lan_ip"
