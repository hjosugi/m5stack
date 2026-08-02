#!/usr/bin/env bash
set -euo pipefail

# 対話で必要な設定を .env に入れるウィザード。
#   setup-wizard.sh stackchan  -> stackchan/deepseek-voice/.env
#   setup-wizard.sh cardputer  -> cardputer/screen-link/.env
# Wi-Fi/IPの取り込みは既存スクリプトを再利用する。実キーは各ファームの.envのみ。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

device=${1:-}
case "$device" in
  stackchan)
    firm_env="$M5_REPO_ROOT/stackchan/deepseek-voice/.env"
    firm_example="$M5_REPO_ROOT/stackchan/deepseek-voice/.env.example"
    ;;
  cardputer)
    firm_env="$M5_REPO_ROOT/cardputer/screen-link/.env"
    firm_example="$M5_REPO_ROOT/cardputer/screen-link/.env.example"
    ;;
  *) die "使用方法: $0 <stackchan|cardputer>" ;;
esac

umask 077
if [[ ! -f $firm_env ]]; then
  if [[ -f $firm_example ]]; then
    cp "$firm_example" "$firm_env"
  else
    : > "$firm_env"
  fi
  chmod 600 "$firm_env"
  log "$firm_env を作成しました。"
fi

get_key() { grep -E "^$1=" "$firm_env" | tail -1 | cut -d= -f2- || true; }

set_key() {
  local key=$1 value=$2 tmp
  tmp=$(mktemp "${firm_env}.tmp.XXXXXX")
  {
    grep -vE "^$key=" "$firm_env" || true
    printf '%s=%s\n' "$key" "$value"
  } > "$tmp"
  chmod 600 "$tmp"
  mv -f -- "$tmp" "$firm_env"
}

ask_value() {
  local key=$1 label=$2 cur value
  cur=$(get_key "$key")
  read -r -p "$label [${cur:-未設定}]: " value
  [[ -n $value ]] && set_key "$key" "$value"
}

# 数値(整数/小数)だけ受け付ける。誤入力は再入力を促す。
ask_number() {
  local key=$1 label=$2 cur value
  cur=$(get_key "$key")
  while true; do
    read -r -p "$label [${cur:-未設定}]: " value
    [[ -z $value ]] && return 0
    if [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      set_key "$key" "$value"
      return 0
    fi
    warn "数値で入力してください（例: 5 または 5.5）。"
  done
}

ask_secret() {
  local key=$1 label=$2 cur value answer
  cur=$(get_key "$key")
  if [[ -n $cur ]]; then
    read -r -p "$label は設定済み。変更する? [y/N] " answer
    [[ $answer == y || $answer == Y ]] || return 0
  fi
  read -r -s -p "$label: " value
  echo
  [[ -n $value ]] && set_key "$key" "$value"
}

install_completion() {
  local shell_name out
  shell_name=$(basename -- "${SHELL:-bash}")
  case "$shell_name" in bash | zsh | fish) ;; *) shell_name=bash ;; esac
  out="$M5_REPO_ROOT/.local/task-completion.$shell_name"
  mkdir -p "$M5_REPO_ROOT/.local"
  if task --completion "$shell_name" > "$out" 2> /dev/null; then
    log "シェル補完を生成: $out"
    log "有効化: '$shell_name' の設定に  source $out  を追記してください。"
  else
    warn "task --completion が使えませんでした。手動導入はgo-taskのdocsを参照してください。"
  fi
}

log "== $device 設定ウィザード =="

read -r -p "いまPCが使用中のWi-Fiを取り込む? [Y/n] " answer
if [[ $answer != n && $answer != N ]]; then
  bash "$SCRIPT_DIR/capture-wifi.sh" --yes --env="$firm_env" || warn "Wi-Fi取り込み失敗。手動で設定してください。"
else
  ask_value WIFI_SSID "WIFI_SSID"
  ask_secret WIFI_PASSWORD "WIFI_PASSWORD"
fi

if [[ $device == stackchan ]]; then
  ask_secret DEEPSEEK_API "DeepSeek APIキー"
  ask_secret STT_API_KEY "STT(OpenAI Whisper) APIキー"
  ask_number MONTHLY_BUDGET_USD "1か月の予算USD"
  read -r -p "完全ローカル(PC上のAI)を使う? [y/N] " answer
  if [[ $answer == y || $answer == Y ]]; then
    set_key PREFER_LOCAL 1
    bash "$SCRIPT_DIR/set-local-host.sh" --yes --env="$firm_env" || warn "LOCAL_HOST自動設定失敗。手動で。"
    ask_value LOCAL_LLM_MODEL "ローカルLLMモデル"
  else
    set_key PREFER_LOCAL 0
  fi
else
  ask_value SCREEN_LINK_SERVER_HOST "PCのIP/ホスト名"
  ask_value SCREEN_LINK_SERVER_PORT "ポート"
  ask_secret SCREEN_LINK_TOKEN "接続トークン(12文字以上)"
  [[ -n $(get_key CARDPUTER_SPEAKER_ENABLED) ]] || set_key CARDPUTER_SPEAKER_ENABLED 0
fi

read -r -p "task のシェル補完を導入する? [y/N] " answer
[[ $answer == y || $answer == Y ]] && install_completion

log "設定完了: $firm_env"
if [[ $device == stackchan ]]; then
  log "次: task deepseek:build （書込みは task deepseek:flash:i）"
else
  log "次: task build-cardputer-screen-link"
fi
