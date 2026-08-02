"""StackChan シミュレータ（host側の分身）。

実機が無くても会話・デバッグ・e2eテストができる。ファーム(DeepSeekVoice)と同じ
ペルソナ・気分(感性)・memory(自己学習)をhost側で再現し、ローカルLLM(Ollama)で応答する。

使い方:
  python sim.py --chat            # ターミナルでテキスト会話（host経由）
  python sim.py --gui             # ミニ窓に顔＋吹き出し（顔をhostに表示）
  python sim.py --once "こんにちは"  # 1発応答（e2e/CI用）

依存は標準ライブラリのみ（urllib/json/tkinter）。tkinterはGUI時だけ読み込む。
設定は stackchan/voice/.env（LOCAL_HOST/LOCAL_LLM_PORT/LOCAL_LLM_MODEL）から読む。
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
_ENV_FILE = _REPO_ROOT / "stackchan" / "voice" / ".env"
_MEMORY_FILE = Path(
    os.environ.get("DSV_MEMORY_FILE", _REPO_ROOT / ".local" / "memory" / "dsv-memory.jsonl")
)
_STATE_FILE = _REPO_ROOT / ".local" / "stackchan-sim" / "state.json"

# ペルソナ（ファームと合わせる。カタカナ・ひらがなのみ）。
PERSONA = (
    "あなたはStackChanという小さな卓上ロボットです。げんきで すこし おっちょこちょい、"
    "あいてを おうえんする やさしい せいかく。かんじを つかわず、カタカナと ひらがなだけで、"
    "3ぶんいないで みじかく こたえてね。"
)

# 感情極性の語（ファームの sentimentOf と同じ）。
_POS = ("すき", "ありがと", "うれし", "たのし", "かわいい", "すごい", "いいね", "だいすき")
_NEG = ("きらい", "やめて", "つまらん", "うざい", "こわい", "かなし", "だめ", "いや")
_REMEMBER = ("おぼえて", "覚えて", "メモして", "めもして")


def read_env(path: Path) -> dict:
    conf = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            conf[key] = value
    return conf


def clampf(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def sentiment_of(text: str) -> int:
    s = 0
    for w in _POS:
        if w in text:
            s += 1
    for w in _NEG:
        if w in text:
            s -= 1
    return s


class Brain:
    """会話の頭脳。LLM呼び出し・気分(感性)・memory(自己学習)を担う。"""

    def __init__(self, conf: dict | None = None):
        conf = conf if conf is not None else read_env(_ENV_FILE)
        host = conf.get("LOCAL_HOST") or "127.0.0.1"
        port = conf.get("LOCAL_LLM_PORT") or "11434"
        self.model = conf.get("LOCAL_LLM_MODEL") or "qwen2.5:3b"
        self.url = f"http://{host}:{port}/v1/chat/completions"
        self.mood, self.energy, self.curiosity = self._load_state()

    # --- 状態（気分・感性）---
    def _load_state(self):
        try:
            d = json.loads(_STATE_FILE.read_text(encoding="utf-8"))
            return float(d.get("mood", 0.0)), float(d.get("energy", 0.5)), float(
                d.get("curiosity", 0.5)
            )
        except (OSError, ValueError):
            return 0.0, 0.5, 0.5

    def _save_state(self):
        _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        _STATE_FILE.write_text(
            json.dumps({"mood": self.mood, "energy": self.energy, "curiosity": self.curiosity}),
            encoding="utf-8",
        )

    def mood_label(self) -> str:
        if self.mood > 0.4:
            return "ごきげん"
        if self.mood < -0.4:
            return "ちょっと ふきげん"
        return "ふつう"

    def learn(self, text: str):
        s = sentiment_of(text)
        self.mood = clampf(self.mood * 0.98 + s * 0.15, -1.0, 1.0)
        self.energy = clampf(self.energy + (0.03 if s > 0 else (-0.03 if s < 0 else 0.0)), 0.0, 1.0)
        self.curiosity = clampf(self.curiosity + 0.01, 0.0, 1.0)
        self._save_state()

    # --- memory（自己学習, ファームとファイル共有）---
    def _append_memory(self, kind: str, text: str):
        _MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
        rec = {"ts": datetime.now(timezone.utc).isoformat(), "kind": kind, "text": text}
        with _MEMORY_FILE.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")

    def facts(self, limit: int = 6) -> list:
        if not _MEMORY_FILE.exists():
            return []
        out = []
        for line in _MEMORY_FILE.read_text(encoding="utf-8").splitlines():
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("kind") == "fact" and rec.get("text"):
                out.append(rec["text"])
        return out[-limit:]

    def try_remember(self, text: str) -> bool:
        if not any(w in text for w in _REMEMBER):
            return False
        fact = text
        for w in _REMEMBER:
            fact = fact.replace(w, "")
        fact = fact.replace("って", "").strip() or text
        self._append_memory("fact", fact)
        return True

    def system_prompt(self) -> str:
        text = PERSONA
        facts = self.facts()
        if facts:
            text += "\nしっていること: " + " ".join("・" + f for f in facts)
        text += f"\nいまの きぶん: {self.mood_label()}。きぶんを へんじに そっと にじませてね。"
        return text

    def call_llm(self, question: str) -> str:
        payload = {
            "model": self.model,
            "stream": False,
            "max_tokens": 512,
            "messages": [
                {"role": "system", "content": self.system_prompt()},
                {"role": "user", "content": question},
            ],
        }
        req = urllib.request.Request(
            self.url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "Authorization": "Bearer ollama"},
        )
        with urllib.request.urlopen(req, timeout=90) as resp:  # noqa: S310 (local trusted host)
            doc = json.loads(resp.read().decode("utf-8"))
        return doc["choices"][0]["message"]["content"].strip()

    def respond(self, question: str) -> str:
        """1往復。おぼえて/学習/LLM応答を処理して返答を返す。"""
        question = question.strip()
        if not question:
            return ""
        if self.try_remember(question):
            return "おぼえたよ！"
        self.learn(question)
        answer = self.call_llm(question)
        self._append_memory("qa", f"{question} => {answer}")
        return answer


def run_chat(brain: Brain):
    print("StackChan（host会話・テキスト）。'quit'で終了。")
    while True:
        try:
            q = input("あなた> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if q in ("quit", "exit", "おわり"):
            break
        if not q:
            continue
        try:
            print(f"スタックちゃん[{brain.mood_label()}]> {brain.respond(q)}")
        except (urllib.error.URLError, OSError) as exc:
            print(f"(LLMに つながらない: {exc}. PCで task local:up してね)", file=sys.stderr)


def run_gui(brain: Brain):
    # GUIのときだけtkinterを読み込む（ヘッドレスCIでの import 失敗を避ける）。
    from face_window import FaceWindow  # noqa: E402  (lazy import)

    FaceWindow(brain).run()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="StackChan シミュレータ")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--chat", action="store_true", help="テキスト会話(REPL)")
    group.add_argument("--gui", action="store_true", help="ミニ窓に顔を表示")
    group.add_argument("--once", metavar="TEXT", help="1発応答して終了(e2e/CI)")
    args = parser.parse_args(argv)

    brain = Brain()
    if args.once is not None:
        print(brain.respond(args.once))
        return 0
    if args.gui:
        run_gui(brain)
        return 0
    run_chat(brain)
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(main())
