"""OpenAI互換の faster-whisper STTサーバ。

StackChanのlocalプロファイルが叩く /v1/audio/transcriptions を提供する。
環境変数:
  STT_MODEL   例 Systran/faster-whisper-small（既定）
  STT_DEVICE  cpu（既定）
  STT_COMPUTE int8（既定・CPU向け）
  STT_PORT    8000（uvicorn起動時に使用）
"""

import os
import tempfile

from faster_whisper import WhisperModel
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse

_MODEL_NAME = os.environ.get("STT_MODEL", "Systran/faster-whisper-small")
_DEVICE = os.environ.get("STT_DEVICE", "cpu")
_COMPUTE = os.environ.get("STT_COMPUTE", "int8")

app = FastAPI(title="m5-local-stt")
_model: WhisperModel | None = None


def _get_model() -> WhisperModel:
    global _model
    if _model is None:
        _model = WhisperModel(_MODEL_NAME, device=_DEVICE, compute_type=_COMPUTE)
    return _model


@app.get("/health")
def health() -> dict:
    return {"ok": True, "model": _MODEL_NAME}


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
