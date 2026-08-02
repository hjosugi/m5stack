#!/usr/bin/env bash
set -euo pipefail

# 開発モード: ローカルAI(STT + Ollama)のログをまとめて表示する。Ctrl-Cで両方停止。
#   [stt]    … faster-whisper STTサーバ（フォアグラウンド, debugログ）
#   [ollama] … Ollama サーバのログ（tailで表示）
# 既存の常駐サーバ(up.sh)が動いていれば止めてから起動する（ポート衝突・二重ログ防止）。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

require_command uv
require_command ss

env_file="$M5_REPO_ROOT/stackchan/voice/.env"
read_key() { grep -E "^$1=" "$env_file" 2> /dev/null | tail -1 | cut -d= -f2- || true; }

stt_port=$(read_key LOCAL_STT_PORT)
stt_port=${stt_port:-8000}
stt_model=$(read_key LOCAL_STT_MODEL)
stt_model=${stt_model:-Systran/faster-whisper-small}
llm_model=$(read_key LOCAL_LLM_MODEL)
llm_model=${llm_model:-qwen2.5:3b}
lan_ip=$(read_key LOCAL_HOST)
lan_ip=${lan_ip:-0.0.0.0}

# 保存先とvenvは .local 配下（ツリーを汚さない）。
export OLLAMA_MODELS=${OLLAMA_MODELS:-"$M5_REPO_ROOT/.local/ollama/models"}
export HF_HOME=${HF_HOME:-"$M5_REPO_ROOT/.local/hf-cache"}
export STT_MODEL=$stt_model
export UV_PROJECT_ENVIRONMENT="$M5_REPO_ROOT/.local/venvs/local-ai"
export OLLAMA_HOST=${OLLAMA_HOST:-0.0.0.0:11434}
mkdir -p "$OLLAMA_MODELS" "$HF_HOME"

ollama_log="$M5_REPO_ROOT/.local/ollama-serve.log"
tail_pid=""

cleanup() {
  log "停止します…"
  [[ -n $tail_pid ]] && kill "$tail_pid" 2> /dev/null || true
  pkill -x ollama 2> /dev/null || true
}
trap cleanup INT TERM EXIT

# 既存の常駐サーバを止める（ポート衝突と二重ログを避ける）。
log "既存のローカルサーバを停止します…"
stt_pids=$(ss -ltnpH "sport = :$stt_port" 2> /dev/null | grep -oP 'pid=\K[0-9]+' | sort -u || true)
for p in $stt_pids; do kill "$p" 2> /dev/null || true; done
pkill -x ollama 2> /dev/null || true
sleep 1

# Ollamaを起動（LAN公開）し、ログをファイルへ。tailで[ollama]付きで流す。
if command -v ollama > /dev/null 2>&1; then
  : > "$ollama_log"
  (ollama serve >> "$ollama_log" 2>&1 &)
  sleep 2
  tail -n +1 -f "$ollama_log" | sed -u 's/^/[ollama] /' &
  tail_pid=$!
  log "モデル $llm_model を確認（未取得ならpull。進捗は[ollama]に出ます）。"
  ollama pull "$llm_model" >> "$ollama_log" 2>&1 || warn "モデル $llm_model のpullに失敗。"
else
  warn "ollama が見つかりません。LLMログは出せません（STTのみ）。"
fi

log "== 開発モード: STT + Ollama のログ（Ctrl-Cで両方停止） =="
log "STT http://$lan_ip:$stt_port  /  LLM http://$lan_ip:11434"

# STTサーバをフォアグラウンド(debug)で。ログは[stt]付き。--reloadは信号処理を複雑にするので使わない。
cd "$SCRIPT_DIR"
uv run --project "$SCRIPT_DIR" \
  uvicorn stt_server:app --host 0.0.0.0 --port "$stt_port" --log-level debug 2>&1 |
  sed -u 's/^/[stt] /'
