#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

require_command arduino-cli
configure_arduino_env

# 吹き出しを小さく/狭くする自前パッチをライブラリへ再適用する。
# arduino-cli lib install（setup時）で純正へ戻るため、毎ビルドで上書きする。
balloon_src="$SCRIPT_DIR/firmware/DeepSeekVoice/vendor/Balloon.h"
balloon_dst="$REPO_ROOT/.local/arduino/user/libraries/M5Stack_Avatar/src/Balloon.h"
if [[ -f $balloon_src && -f $balloon_dst ]] && ! cmp -s "$balloon_src" "$balloon_dst"; then
  cp "$balloon_src" "$balloon_dst"
  log "吹き出しパッチを適用しました: Balloon.h"
fi

source_sketch="$SCRIPT_DIR/firmware/DeepSeekVoice"
build_source="$REPO_ROOT/.local/generated/voice/DeepSeekVoice"
build_dir="$REPO_ROOT/.local/build/voice"
fqbn="m5stack:esp32:m5stack_cores3"

if [[ ${1:-} == --ci ]]; then
  # CIは公開用の例ヘッダだけでコンパイル可否を確認する（実キー不要）。
  sketch=$source_sketch
else
  env_file="$SCRIPT_DIR/.env"
  [[ -f $env_file ]] || die "$env_file がありません。.env.exampleをコピーし実値を設定してください。"

  WIFI_SSID=''
  WIFI_PASSWORD=''
  DEEPSEEK_API=''
  DEEPSEEK_HOST=api.deepseek.com
  DEEPSEEK_MODEL=deepseek-chat
  STT_API_KEY=''
  STT_HOST=api.openai.com
  STT_MODEL=whisper-1
  MONTHLY_BUDGET_USD=5
  PREFER_LOCAL=0
  LOCAL_HOST=''
  LOCAL_LLM_PORT=11434
  LOCAL_LLM_MODEL=qwen2.5:3b
  LOCAL_LLM_KEY=ollama
  LOCAL_STT_PORT=8000
  LOCAL_STT_MODEL=Systran/faster-whisper-small

  line_number=0
  while IFS= read -r line || [[ -n $line ]]; do
    ((line_number += 1))
    line=${line%$'\r'}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == *=* ]] || die "$env_file:$line_number はKEY=VALUE形式ではありません。"
    key=${line%%=*}
    value=${line#*=}
    case "$key" in
      WIFI_SSID | WIFI_PASSWORD | DEEPSEEK_API | DEEPSEEK_HOST | DEEPSEEK_MODEL | \
        STT_API_KEY | STT_HOST | STT_MODEL | MONTHLY_BUDGET_USD | PREFER_LOCAL | \
        LOCAL_HOST | LOCAL_LLM_PORT | LOCAL_LLM_MODEL | LOCAL_LLM_KEY | LOCAL_STT_PORT | \
        LOCAL_STT_MODEL)
        printf -v "$key" '%s' "$value"
        ;;
      *) die "$env_file:$line_number の未対応キー $key を拒否しました。" ;;
    esac
  done < "$env_file"

  [[ -n $WIFI_SSID && -n $WIFI_PASSWORD ]] || die "WIFI_SSID / WIFI_PASSWORD が空です。"
  [[ -n $DEEPSEEK_API ]] || die "DEEPSEEK_API が空です。"
  [[ -n $STT_API_KEY ]] || die "STT_API_KEY が空です。"
  [[ $DEEPSEEK_HOST =~ ^[A-Za-z0-9.-]+$ ]] || die "DEEPSEEK_HOST が不正です。"
  [[ $STT_HOST =~ ^[A-Za-z0-9.-]+$ ]] || die "STT_HOST が不正です。"
  [[ -z $LOCAL_HOST || $LOCAL_HOST =~ ^[A-Za-z0-9.-]+$ ]] || die "LOCAL_HOST が不正です。"
  [[ $PREFER_LOCAL == 0 || $PREFER_LOCAL == 1 ]] || die "PREFER_LOCAL は0か1です。"
  for p in "$LOCAL_LLM_PORT" "$LOCAL_STT_PORT"; do
    if [[ ! $p =~ ^[0-9]+$ ]] || ((10#$p < 1 || 10#$p > 65535)); then
      die "ポート番号が不正です: $p"
    fi
  done
  [[ $MONTHLY_BUDGET_USD =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "MONTHLY_BUDGET_USD が不正です。"
  # 整数なら小数点を補い、常に有効なfloatリテラルにする（5 -> 5.0, 5.5 -> 5.5）。
  if [[ $MONTHLY_BUDGET_USD == *.* ]]; then
    budget_literal=$MONTHLY_BUDGET_USD
  else
    budget_literal=$MONTHLY_BUDGET_USD.0
  fi

  escape_c() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

  mkdir -p "$build_source"
  cp "$source_sketch/DeepSeekVoice.ino" "$source_sketch/deepseek_voice_secrets.example.h" \
    "$build_source/"
  umask 077
  {
    printf '#pragma once\n'
    printf '#define DSV_WIFI_SSID "%s"\n' "$(escape_c "$WIFI_SSID")"
    printf '#define DSV_WIFI_PASSWORD "%s"\n' "$(escape_c "$WIFI_PASSWORD")"
    printf '#define DSV_CLOUD_LLM_HOST "%s"\n' "$(escape_c "$DEEPSEEK_HOST")"
    printf '#define DSV_CLOUD_LLM_PORT 443\n'
    printf '#define DSV_CLOUD_LLM_PATH "/chat/completions"\n'
    printf '#define DSV_CLOUD_LLM_KEY "%s"\n' "$(escape_c "$DEEPSEEK_API")"
    printf '#define DSV_CLOUD_LLM_MODEL "%s"\n' "$(escape_c "$DEEPSEEK_MODEL")"
    printf '#define DSV_CLOUD_STT_HOST "%s"\n' "$(escape_c "$STT_HOST")"
    printf '#define DSV_CLOUD_STT_PORT 443\n'
    printf '#define DSV_CLOUD_STT_PATH "/v1/audio/transcriptions"\n'
    printf '#define DSV_CLOUD_STT_KEY "%s"\n' "$(escape_c "$STT_API_KEY")"
    printf '#define DSV_CLOUD_STT_MODEL "%s"\n' "$(escape_c "$STT_MODEL")"
    printf '#define DSV_LOCAL_HOST "%s"\n' "$(escape_c "$LOCAL_HOST")"
    printf '#define DSV_LOCAL_LLM_PORT %s\n' "$((10#$LOCAL_LLM_PORT))"
    printf '#define DSV_LOCAL_LLM_PATH "/v1/chat/completions"\n'
    printf '#define DSV_LOCAL_LLM_KEY "%s"\n' "$(escape_c "$LOCAL_LLM_KEY")"
    printf '#define DSV_LOCAL_LLM_MODEL "%s"\n' "$(escape_c "$LOCAL_LLM_MODEL")"
    printf '#define DSV_LOCAL_STT_PORT %s\n' "$((10#$LOCAL_STT_PORT))"
    printf '#define DSV_LOCAL_STT_PATH "/v1/audio/transcriptions"\n'
    printf '#define DSV_LOCAL_STT_KEY ""\n'
    printf '#define DSV_LOCAL_STT_MODEL "%s"\n' "$(escape_c "$LOCAL_STT_MODEL")"
    printf '#define DSV_PREFER_LOCAL %s\n' "$PREFER_LOCAL"
    printf '#define DSV_MONTHLY_BUDGET_USD %s\n' "$budget_literal"
  } > "$build_source/deepseek_voice_secrets.h"
  sketch=$build_source
fi

log "StackChan DeepSeek音声版をビルドします（実機への書込みなし）。"
arduino_cli compile \
  --fqbn "$fqbn" \
  --build-path "$build_dir" \
  --warnings all \
  "$sketch"
log "ビルド完了: $build_dir"
