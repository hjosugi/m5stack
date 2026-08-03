#pragma once

namespace {

// ---- 表示ヘルパ（顔は消さず、テキストは小さく吹き出しに出す） ----------------

void say(const String& text) {
  speechBacking = text;
  avatar.setSpeechText(speechBacking.c_str());
  Serial.println(text);
}

void showStatus(const char* text, uint16_t color = TFT_WHITE) {
  (void)color;
  say(text);
}

void showAnswer(const String& question, const String& answer, bool fromCache) {
  (void)fromCache;
  Serial.printf("Q: %s\n", question.c_str());
  say(answer);
}

// ---- 表情・モーション（キャラクタ表現） -------------------------------------
// Avatarは別タスクで常時描画するので、ここで姿勢/視線/表情を書き換えると
// 次のフレームから反映される（まばたき・呼吸は自動で続く）。

void poseReset() {
  avatar.setRotation(0);
  avatar.setScale(1.0f);
  avatar.setPosition(0, 0);
  avatar.setRightGaze(0, 0);
  avatar.setLeftGaze(0, 0);
}

void faceLook(float vertical, float horizontal) {
  avatar.setRightGaze(vertical, horizontal);
  avatar.setLeftGaze(vertical, horizontal);
}

void faceTiltDeg(float deg) { avatar.setRotation(deg * 0.01745329f); }  // 度→ラジアン

// 表情＋首かしげ＋視線＋拡大をまとめて設定する“気分”プリセット。
void emote(Expression exp, float tiltDeg, float gazeV, float gazeH, float scale = 1.0f) {
  avatar.setExpression(exp);
  faceTiltDeg(tiltDeg);
  faceLook(gazeV, gazeH);
  avatar.setScale(scale);
  avatar.setPosition(0, 0);
}

// タッチした側へ顔を向けるための視線オフセット（-1..1）。あたまタッチ時に更新。
float g_listenGazeH = 0.0f;
void moodListening() { emote(Expression::Neutral, 0, -0.2f, g_listenGazeH, 1.03f); }  // 触った方を向く
void moodThinking() { emote(Expression::Doubt, 9, -0.4f, 0.5f, 1.0f); }      // 上を見て考える
void moodHappy() { emote(Expression::Happy, -4, -0.15f, 0.0f, 1.05f); }      // うれしい
void moodSad() { emote(Expression::Sad, 6, 0.5f, -0.2f, 0.97f); }            // しょんぼり

// うなずき（頭を軽く上下）。短時間ブロックするので会話の合間に使う。
void nod(int times = 2) {
  for (int t = 0; t < times; ++t) {
    avatar.setPosition(6, 0);
    delay(110);
    avatar.setPosition(-2, 0);
    delay(110);
  }
  avatar.setPosition(0, 0);
}

}  // namespace
