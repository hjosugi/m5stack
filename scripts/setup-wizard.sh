#!/usr/bin/env bash
set -euo pipefail

# 対話で必要な設定を .env に入れるウィザード。
#   setup-wizard.sh stackchan  -> stackchan/voice/.env
#   setup-wizard.sh cardputer  -> cardputer/screen-link/.env
# Wi-Fi/IPの取り込みは既存スクリプトを再利用する。実キーは各ファームの.envのみ。
#
# 関数(ask/get_key/set_key)は tests/test-setup-wizard.sh から source して
# 単体テストする。対話フローは main() にまとめ、直接実行時のみ動かす。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# 対象ファームの.env（main / テストが設定する）。
firm_env=${firm_env:-}

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

# 値を尋ねる共通関数。挙動:
#   未設定        → 入力を促す（デフォルト）
#   設定済み(通常)→ 変更なければEnterで維持
#   設定済み(秘密)→ 「このまま使う? [Y/n]」でEnter維持、nで変更
#   不正な値      → 上書きせず警告して再入力（Enterで維持/スキップ）
# 引数: key label [pattern] [secret]
#   pattern を渡すと、その正規表現に一致しない入力は拒否（上書きしない）。
#   secret="secret" で入力を伏せる。
# 常に 0 を返す（set -e で落ちないよう if で書く）。
ask() {
  local key=$1 label=$2 pattern=${3:-} secret=${4:-} cur value prompt
  local readflag=()
  cur=$(get_key "$key")
  [[ $secret == secret ]] && readflag=(-s)
  if [[ -n $cur ]]; then
    if [[ $secret == secret ]]; then
      local answer
      read -r -p "$label は設定済み。このまま使う? [Y/n] " answer
      if [[ $answer != n && $answer != N ]]; then
        return 0
      fi
      prompt="$label（新しい値）: "
    else
      prompt="$label（設定済み: $cur）変更なければEnter: "
    fi
  else
    prompt="$label [未設定]: "
  fi
  while true; do
    read -r "${readflag[@]}" -p "$prompt" value
    [[ $secret == secret ]] && echo
    if [[ -z $value ]]; then
      return 0 # 空Enter＝維持(設定済み)/スキップ(未設定)
    fi
    if [[ -n $pattern && ! $value =~ $pattern ]]; then
      warn "形式が正しくありません。上書きしません。入力し直し（Enterで維持）。"
      continue
    fi
    set_key "$key" "$value"
    return 0
  done
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

main() {
  local device=${1:-} firm_example answer
  case "$device" in
    stackchan)
      firm_env="$M5_REPO_ROOT/stackchan/voice/.env"
      firm_example="$M5_REPO_ROOT/stackchan/voice/.env.example"
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

  log "== $device 設定ウィザード =="

  read -r -p "いまPCが使用中のWi-Fiを取り込む? [Y/n] " answer
  if [[ $answer != n && $answer != N ]]; then
    bash "$SCRIPT_DIR/capture-wifi.sh" --yes --env="$firm_env" ||
      warn "Wi-Fi取り込み失敗。手動で設定してください。"
  else
    ask WIFI_SSID "WIFI_SSID"
    ask WIFI_PASSWORD "WIFI_PASSWORD" '^.{8,}$' secret
  fi

  if [[ $device == stackchan ]]; then
    ask DEEPSEEK_API "DeepSeek APIキー" '^[A-Za-z0-9._-]+$' secret
    ask STT_API_KEY "STT(OpenAI Whisper) APIキー" '^[A-Za-z0-9._-]+$' secret
    ask MONTHLY_BUDGET_USD "1か月の予算USD" '^[0-9]+(\.[0-9]+)?$'
    read -r -p "完全ローカル(PC上のAI)を使う? [y/N] " answer
    if [[ $answer == y || $answer == Y ]]; then
      set_key PREFER_LOCAL 1
      bash "$SCRIPT_DIR/set-local-host.sh" --yes --env="$firm_env" ||
        warn "LOCAL_HOST自動設定失敗。手動で。"
      ask LOCAL_LLM_MODEL "ローカルLLMモデル"
    else
      set_key PREFER_LOCAL 0
    fi
  else
    ask SCREEN_LINK_SERVER_HOST "PCのIP/ホスト名" '^[A-Za-z0-9.-]+$'
    ask SCREEN_LINK_SERVER_PORT "ポート" '^[0-9]+$'
    ask SCREEN_LINK_TOKEN "接続トークン(12文字以上)" '^.{12,}$' secret
    if [[ -z $(get_key CARDPUTER_SPEAKER_ENABLED) ]]; then
      set_key CARDPUTER_SPEAKER_ENABLED 0
    fi
  fi

  read -r -p "task のシェル補完を導入する? [y/N] " answer
  if [[ $answer == y || $answer == Y ]]; then
    install_completion
  fi

  log "設定完了: $firm_env"
  if [[ $device == stackchan ]]; then
    log "次: task stackchan:build （書込みは task stackchan:flash:i）"
  else
    log "次: task build-cardputer-screen-link"
  fi
}

# 直接実行時のみ main を動かす（source 時はテストが関数だけ使う）。
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
