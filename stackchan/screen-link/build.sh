#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

env_file="$SCRIPT_DIR/.env"
[[ -f $env_file ]] || die "$env_file がありません。.env.exampleをコピーし、実値を設定してください。"

SCREEN_LINK_SERVER_URL=
SCREEN_LINK_TOKEN=
line_number=0
while IFS= read -r line || [[ -n $line ]]; do
  ((line_number += 1))
  line=${line%$'\r'}
  [[ -z $line || $line == \#* ]] && continue
  [[ $line == *=* ]] || die "$env_file:$line_number はKEY=VALUE形式ではありません。"
  key=${line%%=*}
  value=${line#*=}
  case "$key" in
    SCREEN_LINK_SERVER_URL | SCREEN_LINK_TOKEN) printf -v "$key" '%s' "$value" ;;
    *) die "$env_file:$line_number の未対応キー $key を拒否しました。" ;;
  esac
done < "$env_file"

if [[ ! $SCREEN_LINK_SERVER_URL =~ ^http://[A-Za-z0-9.-]+:([0-9]{1,5})$ ]]; then
  die "SCREEN_LINK_SERVER_URLはhttp://LAN-IP:port形式で指定してください。"
fi
server_port=$((10#${BASH_REMATCH[1]}))
if ((server_port < 1 || server_port > 65535)); then
  die "SCREEN_LINK_SERVER_URLのportが不正です。"
fi
[[ $SCREEN_LINK_TOKEN =~ ^[A-Za-z0-9_-]{12,128}$ ]] || die "SCREEN_LINK_TOKENは12〜128文字の英数字・_・-だけを使用してください。"

generated_dir="$REPO_ROOT/.local/generated/stackchan-screen-link"
generated_defaults="$generated_dir/sdkconfig.defaults.local"
build_dir="$REPO_ROOT/.local/build/stackchan-screen-link-ja"
mkdir -p "$generated_dir"
umask 077
{
  printf 'CONFIG_STACKCHAN_SERVER_URL="%s"\n' "$SCREEN_LINK_SERVER_URL"
  printf 'CONFIG_SCREEN_LINK_AUTH_TOKEN="%s"\n' "$SCREEN_LINK_TOKEN"
} > "$generated_defaults"

M5_STACKCHAN_BUILD_DIR=$build_dir \
  M5_STACKCHAN_EXTRA_DEFAULTS=$generated_defaults \
  M5_STACKCHAN_EXTRA_COMPONENT_DIRS="$SCRIPT_DIR/components/screen_link_auth" \
  "$REPO_ROOT/scripts/build-stackchan-factory.sh"

grep -Fqx "CONFIG_STACKCHAN_SERVER_URL=\"$SCREEN_LINK_SERVER_URL\"" "$build_dir/sdkconfig" || die "PC relay URLが生成sdkconfigへ反映されていません。"
grep -q '^CONFIG_SCREEN_LINK_AUTH_TOKEN=' "$build_dir/sdkconfig" || die "画面リンクtoken設定が生成sdkconfigへ反映されていません。"
nm_path=$(find "$REPO_ROOT/.local/espressif/tools/xtensa-esp-elf" -type f -name 'xtensa-esp32s3-elf-nm' -perm -u+x -print -quit)
[[ -n $nm_path ]] || die "ESP32-S3 nmが見つかりません。"
"$nm_path" -C "$build_dir/stack-chan.elf" | grep -E ' [Tt] secret_logic::generate_auth_token' > /dev/null ||
  die "認証tokenのstrong overrideが最終ファームウェアへリンクされていません。"
grep -F 'screen_link_auth.cpp.obj' "$build_dir/stack-chan.map" > /dev/null ||
  die "画面リンク認証componentがlink mapにありません。"
log "StackChan画面リンク版のビルドが完了しました（実機への書込みなし）。"
log "成果物: $build_dir"
