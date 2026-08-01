#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

require_command arduino-cli
configure_arduino_env

source_sketch="$SCRIPT_DIR/firmware/ScreenLinkCardputer"
build_source="$REPO_ROOT/.local/generated/cardputer-screen-link/ScreenLinkCardputer"
build_dir="$REPO_ROOT/.local/build/cardputer-screen-link"

if [[ ${1:-} == --ci ]]; then
  sketch=$source_sketch
else
  env_file="$SCRIPT_DIR/.env"
  [[ -f $env_file ]] || die "$env_file がありません。.env.exampleをコピーし、実値を設定してください。"

  WIFI_SSID=
  WIFI_PASSWORD=
  SCREEN_LINK_SERVER_HOST=
  SCREEN_LINK_SERVER_PORT=
  SCREEN_LINK_TOKEN=
  CARDPUTER_SPEAKER_ENABLED=0

  line_number=0
  while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    line=${line%$'\r'}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *=* ]] || die "$env_file:$line_number はKEY=VALUE形式ではありません。"
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      WIFI_SSID | WIFI_PASSWORD | SCREEN_LINK_SERVER_HOST | SCREEN_LINK_SERVER_PORT | SCREEN_LINK_TOKEN | CARDPUTER_SPEAKER_ENABLED)
        printf -v "$key" '%s' "$value"
        ;;
      *) die "$env_file:$line_number の未対応キー $key を拒否しました。" ;;
    esac
  done < "$env_file"

  [[ -n $WIFI_SSID && -n $WIFI_PASSWORD ]] || die "Wi-Fi設定が空です。"
  [[ $SCREEN_LINK_SERVER_HOST =~ ^[A-Za-z0-9.-]+$ ]] || die "SCREEN_LINK_SERVER_HOSTはIPv4またはhostnameだけを指定してください。"
  if [[ ! $SCREEN_LINK_SERVER_PORT =~ ^[0-9]+$ ]]; then
    die "SCREEN_LINK_SERVER_PORTが不正です。"
  fi
  port_number=$((10#$SCREEN_LINK_SERVER_PORT))
  if ((port_number < 1 || port_number > 65535)); then
    die "SCREEN_LINK_SERVER_PORTが不正です。"
  fi
  [[ $SCREEN_LINK_TOKEN =~ ^[A-Za-z0-9_-]{12,128}$ ]] || die "SCREEN_LINK_TOKENは12〜128文字の英数字・_・-だけを使用してください。"
  [[ $CARDPUTER_SPEAKER_ENABLED == 0 || $CARDPUTER_SPEAKER_ENABLED == 1 ]] || die "CARDPUTER_SPEAKER_ENABLEDは0または1です。"

  escape_c_string() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
  }

  mkdir -p "$build_source"
  cp "$source_sketch/ScreenLinkCardputer.ino" "$source_sketch/screen_link_secrets.example.h" "$build_source/"
  umask 077
  {
    printf '#pragma once\n'
    printf '#define SCREEN_LINK_WIFI_SSID "%s"\n' "$(escape_c_string "$WIFI_SSID")"
    printf '#define SCREEN_LINK_WIFI_PASSWORD "%s"\n' "$(escape_c_string "$WIFI_PASSWORD")"
    printf '#define SCREEN_LINK_SERVER_HOST "%s"\n' "$(escape_c_string "$SCREEN_LINK_SERVER_HOST")"
    printf '#define SCREEN_LINK_SERVER_PORT %s\n' "$port_number"
    printf '#define SCREEN_LINK_TOKEN "%s"\n' "$SCREEN_LINK_TOKEN"
    printf '#define SCREEN_LINK_ENABLE_SPEAKER %s\n' "$CARDPUTER_SPEAKER_ENABLED"
  } > "$build_source/screen_link_secrets.h"
  sketch=$build_source
fi

log "Cardputer Adv画面リンクclientをビルドします（実機への書込みなし）。"
arduino_cli compile \
  --fqbn m5stack:esp32:m5stack_cardputer \
  --build-path "$build_dir" \
  --warnings all \
  "$sketch"
log "ビルド完了: $build_dir"
