#!/usr/bin/env bash
set -euo pipefail

# PC側の完全ローカルAIを起動する。StackChanのlocalプロファイルが接続する
# OpenAI互換エンドポイントを用意する:
#   LLM: Ollama            http://<PC>:11434/v1/chat/completions
#   STT: faster-whisper系  http://<PC>:8000/v1/audio/transcriptions
# GPUやモデルの導入方針はPCに依存するため、本スクリプトは前提を確認して案内する。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

# 対象ファームの.envからモデル/ポートを読む（無ければ既定）。
env_file="$M5_REPO_ROOT/stackchan/deepseek-voice/.env"
if [[ -f $env_file ]]; then
  from_env=$(grep -E '^LOCAL_LLM_MODEL=' "$env_file" | tail -1 | cut -d= -f2-)
  [[ -n $from_env ]] && LOCAL_LLM_MODEL=$from_env
  from_env=$(grep -E '^LOCAL_STT_PORT=' "$env_file" | tail -1 | cut -d= -f2-)
  [[ -n $from_env ]] && LOCAL_STT_PORT=$from_env
  from_env=$(grep -E '^LOCAL_STT_MODEL=' "$env_file" | tail -1 | cut -d= -f2-)
  [[ -n $from_env ]] && LOCAL_STT_MODEL=$from_env
fi
llm_model=${LOCAL_LLM_MODEL:-qwen2.5:3b}
stt_port=${LOCAL_STT_PORT:-8000}
stt_model=${LOCAL_STT_MODEL:-Systran/faster-whisper-small}

# モデルの保存先。既定は /mnt/data 上の repo .local/。OLLAMA_MODELS 環境変数で上書き可。
export OLLAMA_MODELS=${OLLAMA_MODELS:-"$M5_REPO_ROOT/.local/ollama/models"}
mkdir -p "$OLLAMA_MODELS"
log "モデル保存先: $OLLAMA_MODELS （OLLAMA_MODELS で変更可）"

lan_ip=$(grep -E '^LOCAL_HOST=' "$env_file" 2> /dev/null | tail -1 | cut -d= -f2- || true)
[[ -n ${lan_ip:-} ]] || lan_ip="<PCのLAN IP（.envのLOCAL_HOST）>"

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

# --- STT (faster-whisper OpenAI互換サーバ: pc/local-ai/stt_server.py) ---
# whisperモデルは HuggingFace から取得。保存先は /mnt/data 上の .local/hf-cache。
export HF_HOME=${HF_HOME:-"$M5_REPO_ROOT/.local/hf-cache"}
mkdir -p "$HF_HOME"
export STT_MODEL=$stt_model
# venvは .local/ 配下に置く（リポジトリのツリーを汚さない・各種checkの対象外）。
export UV_PROJECT_ENVIRONMENT="$M5_REPO_ROOT/.local/venvs/local-ai"
if command -v uv > /dev/null 2>&1; then
  if curl -fsS "http://127.0.0.1:$stt_port/health" > /dev/null 2>&1; then
    log "STT既に起動済み: http://$lan_ip:$stt_port/v1/audio/transcriptions"
  else
    log "STTサーバを起動します（$stt_model, 保存先: $HF_HOME）。初回はモデルDLで時間がかかる。"
    (cd "$SCRIPT_DIR" && uv run --project "$SCRIPT_DIR" \
      uvicorn stt_server:app --host 0.0.0.0 --port "$stt_port" \
      > "$M5_REPO_ROOT/.local/stt-server.log" 2>&1 &)
    log "STT起動中: http://$lan_ip:$stt_port （ログ: .local/stt-server.log）"
  fi
else
  warn "uv が見つかりません。nix develop 内で実行してください。"
fi
log ""
log "LLM+STTが起動したら、StackChan上部タップで LOCAL に切り替えれば完全ローカルです。"
