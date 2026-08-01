#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_command curl
require_command jq

target=
if (($# > 0)); then
  [[ ${1:-} == --target && $# == 2 ]] || die "使用方法: $0 [--target cardputer|stackchan]"
  target=$2
  case "$target" in
    cardputer | stackchan) ;;
    *) die "targetはcardputerまたはstackchanです: $target" ;;
  esac
fi

status_url=${SCREEN_LINK_STATUS_URL:-}
if [[ -z $status_url ]]; then
  env_file="$M5_REPO_ROOT/pc/screen-link/.env"
  [[ -f $env_file ]] || die "$env_file がありません。.env.exampleをコピーするかURL=http://host:portを指定してください。"

  relay_host=0.0.0.0
  relay_port=8765
  line_number=0
  while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    line=${line%$'\r'}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *=* ]] || die "$env_file:$line_number はKEY=VALUE形式ではありません。"
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      SCREEN_LINK_HOST) relay_host=$value ;;
      SCREEN_LINK_PORT) relay_port=$value ;;
      SCREEN_LINK_TOKEN) ;;
      *) die "$env_file:$line_number の未対応キー $key を拒否しました。" ;;
    esac
  done < "$env_file"

  if [[ ! $relay_port =~ ^[0-9]+$ ]] || ((relay_port < 1 || relay_port > 65535)); then
    die "SCREEN_LINK_PORTが不正です。"
  fi
  case "$relay_host" in
    0.0.0.0) relay_host=127.0.0.1 ;;
    :: | "[::]") relay_host="[::1]" ;;
    *:*) relay_host="[$relay_host]" ;;
  esac
  status_url="http://$relay_host:$relay_port"
fi

status_url=${status_url%/}
[[ $status_url =~ ^https?://(\[[0-9A-Fa-f:]+\]|[A-Za-z0-9.-]+)(:[0-9]+)?$ ]] || die "URLはhttp(s)://host:port形式で指定してください。"

response=$(curl --fail --silent --show-error --max-time 5 "$status_url/healthz") || die "relayへ接続できません: $status_url"
printf '%s\n' "$response" | jq -e '
  .status == "ok"
  and (.producers | type == "number")
  and (.cardputer | type == "number")
  and (.stackchan | type == "number")
' > /dev/null || die "relayの応答形式が不正です。"

if [[ -n $target ]]; then
  printf '%s\n' "$response" | jq -r --arg target "$target" '"\($target)=\(.[$target])"'
else
  printf '%s\n' "$response" | jq -r '"relay=ok producers=\(.producers) cardputer=\(.cardputer) stackchan=\(.stackchan)"'
fi
