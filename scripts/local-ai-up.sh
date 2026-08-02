#!/usr/bin/env bash
set -euo pipefail

# PC側の完全ローカルAIを起動する。StackChanのlocalプロファイルが接続する
# OpenAI互換エンドポイントを用意する:
#   LLM: Ollama            http://<PC>:11434/v1/chat/completions
#   STT: faster-whisper系  http://<PC>:8000/v1/audio/transcriptions
# GPUやモデルの導入方針はPCに依存するため、本スクリプトは前提を確認して案内する。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

llm_model=${LOCAL_LLM_MODEL:-qwen2.5:3b}
stt_port=${LOCAL_STT_PORT:-8000}

lan_ip=$(hostname -I 2> /dev/null | awk '{print $1}')
[[ -n $lan_ip ]] || lan_ip="<PCのLAN IP>"

log "== 完全ローカルAI 起動チェック =="
log "StackChanの .env に LOCAL_HOST=$lan_ip を設定してください。"
log ""

# --- LLM (Ollama) ---
if command -v ollama > /dev/null 2>&1; then
  if ! curl -fsS "http://127.0.0.1:11434/api/tags" > /dev/null 2>&1; then
    log "Ollamaを起動します (ollama serve をバックグラウンドで)。"
    (ollama serve > /dev/null 2>&1 &)
    sleep 2
  fi
  log "モデル $llm_model を確認します（未取得なら pull）。"
  ollama pull "$llm_model"
  log "LLM OK: http://$lan_ip:11434/v1/chat/completions ($llm_model)"
else
  warn "ollama が見つかりません。https://ollama.com からインストールし、再実行してください。"
fi
log ""

# --- STT (faster-whisper, OpenAI互換) ---
# 例1: speaches (uvx)   例2: docker fedirz/faster-whisper-server
if command -v uvx > /dev/null 2>&1; then
  log "STTサーバの例: uvx speaches --port $stt_port"
  log "  起動後 http://$lan_ip:$stt_port/v1/audio/transcriptions が使えます。"
elif command -v docker > /dev/null 2>&1; then
  log "STTサーバの例(docker): docker run -p $stt_port:8000 fedirz/faster-whisper-server:latest-cpu"
else
  warn "STTサーバ用に uvx か docker を用意してください（faster-whisper系のOpenAI互換サーバ）。"
fi
log ""
log "両方起動したら、StackChanの画面上部をタップして LOCAL に切り替えれば完全ローカルになります。"
