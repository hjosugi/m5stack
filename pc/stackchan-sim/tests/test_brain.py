"""StackChan シミュレータ Brain の e2e/単体テスト（ヘッドレス）。

LLM呼び出しはスタブ化し、会話パイプライン（記憶・感情・memory）を検証する。
tkinterは読み込まない（face_windowをimportしない）ので、CI/ヘッドレスで走る。
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import sim  # noqa: E402


class BrainTest(unittest.TestCase):
    def setUp(self):
        # memory/state を一時ディレクトリへ隔離する。
        self._tmp = tempfile.TemporaryDirectory()
        tmp = Path(self._tmp.name)
        sim._MEMORY_FILE = tmp / "mem.jsonl"
        sim._STATE_FILE = tmp / "state.json"
        self.brain = sim.Brain(conf={"LOCAL_HOST": "x", "LOCAL_LLM_PORT": "1", "LOCAL_LLM_MODEL": "m"})
        self.brain.call_llm = lambda q: "テスト おうとう"

    def tearDown(self):
        self._tmp.cleanup()

    def test_sentiment(self):
        self.assertGreater(sim.sentiment_of("だいすき"), 0)
        self.assertLess(sim.sentiment_of("きらい"), 0)
        self.assertEqual(sim.sentiment_of("てんき"), 0)

    def test_mood_moves_with_sentiment(self):
        before = self.brain.mood
        self.brain.learn("だいすき ありがとう")
        self.assertGreater(self.brain.mood, before)
        self.brain.mood = 0.0
        self.brain.learn("きらい やめて")
        self.assertLess(self.brain.mood, 0.0)

    def test_remember_stores_fact(self):
        reply = self.brain.respond("わたしは ねこが すき っておぼえて")
        self.assertEqual(reply, "おぼえたよ！")
        facts = self.brain.facts()
        self.assertTrue(any("ねこ" in f for f in facts))

    def test_fact_injected_into_prompt(self):
        self.brain.respond("なまえは たろう っておぼえて")
        self.assertIn("たろう", self.brain.system_prompt())

    def test_respond_logs_qa(self):
        self.brain.respond("こんにちは")
        lines = sim._MEMORY_FILE.read_text(encoding="utf-8").splitlines()
        kinds = [json.loads(x)["kind"] for x in lines]
        self.assertIn("qa", kinds)

    def test_mood_label_boundaries(self):
        self.brain.mood = 0.9
        self.assertEqual(self.brain.mood_label(), "ごきげん")
        self.brain.mood = -0.9
        self.assertEqual(self.brain.mood_label(), "ちょっと ふきげん")


if __name__ == "__main__":
    unittest.main()
