#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
env_file="$SCRIPT_DIR/.env"
[[ -f $env_file ]] || { printf 'エラー: %s がありません。.env.exampleをコピーしてください。\n' "$env_file" >&2; exit 1; }

SCREEN_LINK_HOST=0.0.0.0
SCREEN_LINK_PORT=8765
SCREEN_LINK_TOKEN=
line_number=0
while IFS= read -r line || [[ -n $line ]]; do
  ((line_number += 1))
  line=${line%$'\r'}
  [[ -z $line || $line == \#* ]] && continue
  [[ $line == *=* ]] || { printf 'エラー: %s:%d はKEY=VALUE形式ではありません。\n' "$env_file" "$line_number" >&2; exit 1; }
  key=${line%%=*}
  value=${line#*=}
  case "$key" in
    SCREEN_LINK_HOST | SCREEN_LINK_PORT | SCREEN_LINK_TOKEN) printf -v "$key" '%s' "$value" ;;
    *) printf 'エラー: %s:%d の未対応キー %s を拒否しました。\n' "$env_file" "$line_number" "$key" >&2; exit 1 ;;
  esac
done < "$env_file"

[[ $SCREEN_LINK_HOST =~ ^[A-Za-z0-9.:-]+$ ]] || { echo 'エラー: SCREEN_LINK_HOSTが不正です。' >&2; exit 1; }
[[ $SCREEN_LINK_PORT =~ ^[0-9]+$ ]] && ((SCREEN_LINK_PORT >= 1 && SCREEN_LINK_PORT <= 65535)) || { echo 'エラー: SCREEN_LINK_PORTが不正です。' >&2; exit 1; }
[[ $SCREEN_LINK_TOKEN =~ ^[A-Za-z0-9_-]{12,128}$ ]] || { echo 'エラー: SCREEN_LINK_TOKENは12〜128文字の英数字・_・-です。' >&2; exit 1; }

export SCREEN_LINK_HOST SCREEN_LINK_PORT SCREEN_LINK_TOKEN
exec uv run --project "$SCRIPT_DIR" --frozen m5-screen-link
