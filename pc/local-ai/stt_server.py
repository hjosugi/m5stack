"""OpenAI互換の faster-whisper STTサーバ + 自己学習メモリ。

StackChanのlocalプロファイルが叩く:
  /v1/audio/transcriptions  … 音声→文字
  /memory (POST/GET)        … 自己学習データを host側(このrepo)へ蓄積
環境変数:
  STT_MODEL   例 Systran/faster-whisper-small（既定）
  STT_DEVICE  cpu（既定）
  STT_COMPUTE int8（既定・CPU向け）
  STT_PORT    8000（uvicorn起動時に使用）
  DSV_MEMORY_FILE  学習データの保存先（既定 <repo>/.local/memory/dsv-memory.jsonl）
"""

import json
import os
import tempfile
import threading
from datetime import datetime, timezone
from pathlib import Path

from faster_whisper import WhisperModel
from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse

_MODEL_NAME = os.environ.get("STT_MODEL", "Systran/faster-whisper-small")
_DEVICE = os.environ.get("STT_DEVICE", "cpu")
_COMPUTE = os.environ.get("STT_COMPUTE", "int8")

# 自己学習データは repo 内の .local（gitignore）に貯める。
_REPO_ROOT = Path(__file__).resolve().parents[2]
_MEMORY_FILE = Path(
    os.environ.get("DSV_MEMORY_FILE", _REPO_ROOT / ".local" / "memory" / "dsv-memory.jsonl")
)

app = FastAPI(title="m5-local-stt")
_model: WhisperModel | None = None


def _get_model() -> WhisperModel:
    global _model
    if _model is None:
        _model = WhisperModel(_MODEL_NAME, device=_DEVICE, compute_type=_COMPUTE)
    return _model


@app.on_event("startup")
def _warmup() -> None:
    # 端末の初回リクエストが遅くならないよう、起動時に別スレッドでモデルを読み込む。
    threading.Thread(target=_get_model, daemon=True).start()


@app.get("/health")
def health() -> dict:
    return {"ok": True, "model": _MODEL_NAME, "loaded": _model is not None}


@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    model: str = Form("whisper-1"),
    response_format: str = Form("json"),
):
    audio = await file.read()
    with tempfile.NamedTemporaryFile(suffix=".wav") as handle:
        handle.write(audio)
        handle.flush()
        segments, _info = _get_model().transcribe(handle.name, language="ja")
        text = "".join(segment.text for segment in segments).strip()
    if response_format == "text":
        return PlainTextResponse(text)
    return JSONResponse({"text": text})


@app.post("/memory")
async def memory_add(request: Request) -> dict:
    """StackChanの自己学習データを1行JSONで追記する（localモード時に送られる）。"""
    try:
        payload = await request.json()
    except (ValueError, TypeError):
        payload = {}
    text = str(payload.get("text", "")).strip()
    if not text:
        return JSONResponse({"ok": False, "error": "empty text"}, status_code=400)
    record = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "kind": str(payload.get("kind", "note")),
        "text": text,
    }
    _MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    with _MEMORY_FILE.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    return {"ok": True}


@app.get("/memory")
def memory_list(limit: int = 20) -> dict:
    """蓄積した学習データの末尾limit件を返す（確認・端末側の取り込み用）。"""
    if not _MEMORY_FILE.exists():
        return {"count": 0, "items": []}
    lines = _MEMORY_FILE.read_text(encoding="utf-8").splitlines()
    limit = max(1, min(limit, 200))
    items = []
    for line in lines[-limit:]:
        try:
            items.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return {"count": len(items), "items": items}
