#pragma once

namespace {

// ---- 個性・感性（学習で少しずつ変化する） ----------------------------------
// 単語(FACT)だけでなく「きぶん/テンション/こうきしん」を会話から学習し、
// 表情の出やすさ・返事のトーンに反映する。まれに自然変動もする（気まぐれ）。
// より高度な“topicごとの好き嫌い/確率モデル”はroadmap参照。

float persMood = 0.0f;       // -1(ふきげん) .. +1(ごきげん)
float persEnergy = 0.5f;     // 0..1 テンション
float persCuriosity = 0.5f;  // 0..1 こうきしん

float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }

void loadPersonality() {
  persMood = prefs.getFloat("p_mood", 0.0f);
  persEnergy = prefs.getFloat("p_energy", 0.5f);
  persCuriosity = prefs.getFloat("p_curio", 0.5f);
}

void savePersonality() {
  prefs.putFloat("p_mood", persMood);
  prefs.putFloat("p_energy", persEnergy);
  prefs.putFloat("p_curio", persCuriosity);
}

// ユーザ発話のごく簡単な感情極性（+すき/ありがと 〜 -きらい/やめて）。
int sentimentOf(const String& t) {
  static const char* const kPos[] = {"すき",   "ありがと", "うれし", "たのし",
                                     "かわいい", "すごい",  "いいね", "だいすき"};
  static const char* const kNeg[] = {"きらい", "やめて", "つまらん", "うざい",
                                     "こわい", "かなし", "だめ",   "いや"};
  int s = 0;
  for (auto w : kPos)
    if (t.indexOf(w) >= 0) s++;
  for (auto w : kNeg)
    if (t.indexOf(w) >= 0) s--;
  return s;
}

// 会話1回ごとに個性を少し更新（学習）。気分は自然に中庸へ戻る。
void learnFromUtterance(const String& q) {
  int s = sentimentOf(q);
  persMood = clampf(persMood * 0.98f + s * 0.15f, -1.0f, 1.0f);
  persEnergy = clampf(persEnergy + (s > 0 ? 0.03f : (s < 0 ? -0.03f : 0.0f)), 0.0f, 1.0f);
  persCuriosity = clampf(persCuriosity + 0.01f, 0.0f, 1.0f);  // 会話するほど好奇心↑
  savePersonality();
}

// 現在の気分を短いラベルに（プロンプト注入・表情選択に使う）。
String moodLabel() {
  if (persMood > 0.4f) return "ごきげん";
  if (persMood < -0.4f) return "ちょっと ふきげん";
  return "ふつう";
}
String energyLabel() {
  if (persEnergy > 0.6f) return "げんき";
  if (persEnergy < 0.3f) return "のんびり";
  return "ふつう";
}

// 個性に応じた「答えるときの表情」。気分で確率的に出る顔が変わる。
void moodByPersonality() {
  if (persMood > 0.3f) {
    moodHappy();
  } else if (persMood < -0.3f) {
    emote(Expression::Doubt, 6, 0.2f, -0.3f);
  } else {
    emote(Expression::Neutral, 2, 0.0f, 0.2f, 1.02f);
  }
}

}  // namespace
