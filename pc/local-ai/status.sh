#!/usr/bin/env bash
set -euo pipefail

# 完全ローカルAI（Ollama + faster-whisper STT）の生死を確認する。
# 起動は up.sh。ここでは各エンドポイントに触って OK/NG を表示するだけ。

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/../.." && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

require_command curl

env_file="$M5_REPO_ROOT/stackchan/voice/.env"
read_key() { grep -E "^$1=" "$env_file" 2> /dev/null | tail -1 | cut -d= -f2- || true; }

llm_port=11434
stt_port=$(read_key LOCAL_STT_PORT)
stt_port=${stt_port:-8000}
llm_model=$(read_key LOCAL_LLM_MODEL)
llm_model=${llm_model:-qwen2.5:3b}
lan_ip=$(read_key LOCAL_HOST)
lan_ip=${lan_ip:-127.0.0.1}

ok=0
ng=0

# $1=ラベル $2=URL （200系で疎通OK）
probe() {
  local label=$1 url=$2
  if curl -fsS --max-time 5 "$url" > /dev/null 2>&1; then
    log "OK  $label  ($url)"
    ok=$((ok + 1))
    return 0
  fi
  warn "NG  $label  ($url)"
  ng=$((ng + 1))
  return 0
}

log "== 完全ローカルAI 状態確認 (端末が繋ぐ LOCAL_HOST=$lan_ip) =="

# 端末は LAN(LOCAL_HOST) 経由で繋ぐので、その宛先で確認する。
# LLM: Ollamaのモデル一覧。
if probe "LLM (Ollama)" "http://$lan_ip:$llm_port/api/tags"; then
  if curl -fsS --max-time 5 "http://$lan_ip:$llm_port/api/tags" 2> /dev/null |
    grep -q "\"$llm_model\""; then
    log "    モデル $llm_model: 取得済み"
  else
    warn "    モデル $llm_model: 未取得（task local:up で pull されます）"
  fi
elif curl -fsS --max-time 5 "http://127.0.0.1:$llm_port/api/tags" > /dev/null 2>&1; then
  # ローカルでは応答するがLANから見えない=127.0.0.1のみで待受け。
  warn "    Ollamaは 127.0.0.1 のみで待受け。端末から繋がりません。"
  warn "    → pkill -x ollama してから task local:up（OLLAMA_HOST=0.0.0.0で再起動）"
fi

# STT: faster-whisper OpenAI互換サーバの /health。
probe "STT (faster-whisper)" "http://$lan_ip:$stt_port/health"

log ""
if ((ng == 0)); then
  log "すべて稼働中。StackChanを LOCAL にすれば完全ローカルで動きます。"
else
  warn "未起動があります。'task local:up' で起動してください（ログ: .local/stt-server.log）。"
  exit 1
fi
