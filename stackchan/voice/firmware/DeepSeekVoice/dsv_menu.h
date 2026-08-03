#pragma once

namespace {

// ---- 会話モード / 自発モード / メニュー -------------------------------------

bool proactiveOn = false;  // 自発発話は既定OFF。メニューでON。
bool handsFree = false;    // 呼びかけ会話（常時listen）。既定OFF。
uint32_t proactiveIntervalMs = 5UL * 60 * 1000;
uint32_t lastProactiveMs = 0;
bool inMenu = false;
int menuIndex = 0;

// 自発発話の“気分”。台詞＋表情＋首かしげ＋視線をセットにしてキャラを出す。
struct IdleMood {
  const char* line;
  Expression exp;
  float tilt;
  float gazeV;
  float gazeH;
};
const IdleMood kIdleMoods[] = {
    {"ひまだなぁ…", Expression::Sleepy, -7, 0.4f, -0.3f},
    {"なにか てつだおうか？", Expression::Happy, 5, -0.2f, 0.4f},
    {"きょうも いいひに なあれ", Expression::Happy, 0, -0.5f, 0.0f},
    {"はなしかけてね！", Expression::Neutral, 4, 0.0f, 0.4f},
    {"げんきー？", Expression::Happy, -5, 0.2f, -0.4f},
    {"むむっ、なにか かんがえ中", Expression::Doubt, 8, -0.4f, 0.5f},
    {"ふぁ〜、ねむい…", Expression::Sleepy, 9, 0.5f, 0.0f},
    {"わくわくしてきた！", Expression::Happy, -7, -0.4f, 0.3f},
    {"きみは えらいなあ", Expression::Happy, 3, -0.1f, -0.3f},
};

void loadSettings() {
  proactiveOn = prefs.getBool("pro_on", false);
  handsFree = prefs.getBool("hf_on", false);
  uint32_t minutes = prefs.getUInt("pro_min", 5);
  if (minutes < 1) minutes = 1;
  proactiveIntervalMs = minutes * 60UL * 1000;
  lastProactiveMs = millis();
}

void resetProactiveTimer() { lastProactiveMs = millis(); }

// 設定はパネルで表示する。描画中は顔タスクを止めておく（avatar.suspend）。
// 項目をタッチすると切り替わり、「とじる」で保存して終了する。
constexpr int kMenuCount = 5;
constexpr int kMenuRowsY0 = 30;  // 項目リストの開始y
constexpr int kMenuRowH = 40;    // 1項目の高さ

// タッチy座標→項目index（0..kMenuCount-1）。
int menuRowAt(int y) {
  int idx = (y - kMenuRowsY0) / kMenuRowH;
  if (idx < 0) idx = 0;
  if (idx >= kMenuCount) idx = kMenuCount - 1;
  return idx;
}

void drawMenuPanel() {
  auto& d = M5.Display;
  uint32_t minutes = proactiveIntervalMs / 60000;
  String rows[kMenuCount];
  rows[0] = String("モード: ") + (backendLocal ? "local" : "cloud");
  rows[1] = String("かいわ: ") + (handsFree ? "よびかけ" : "タッチ");
  rows[2] = String("じはつ: ") + (proactiveOn ? "ON" : "OFF");
  rows[3] = String("かんかく: ") + minutes + "ふん";
  rows[4] = "とじる";

  d.startWrite();
  d.fillScreen(TFT_BLACK);
  d.fillRect(0, 0, d.width(), 24, TFT_DARKGREY);
  d.setFont(&fonts::lgfxJapanGothic_16);
  d.setTextDatum(ML_DATUM);
  d.setTextColor(TFT_WHITE, TFT_DARKGREY);
  d.drawString("せってい（タッチで きりかえ）", 10, 12);

  // 各項目。タッチで切替。最後の「とじる」で保存して終了。
  for (int i = 0; i < kMenuCount; ++i) {
    int y = kMenuRowsY0 + i * kMenuRowH;
    bool close = (i == kMenuCount - 1);
    uint16_t bg = close ? TFT_DARKGREEN : TFT_NAVY;
    d.fillRoundRect(8, y, d.width() - 16, kMenuRowH - 6, 6, bg);
    d.setTextColor(TFT_WHITE, bg);
    d.setTextDatum(ML_DATUM);
    d.drawString(rows[i].c_str(), 18, y + (kMenuRowH - 6) / 2);
  }
  d.endWrite();
}

// 選択中の項目を決定（トグル/変更/閉じる）。
void menuApply() {
  uint32_t minutes = proactiveIntervalMs / 60000;
  switch (menuIndex) {
    case 0:
      backendLocal = !backendLocal;  // cloud ↔ local
      break;
    case 1:
      handsFree = !handsFree;
      prefs.putBool("hf_on", handsFree);
      break;
    case 2:
      proactiveOn = !proactiveOn;
      prefs.putBool("pro_on", proactiveOn);
      break;
    case 3:
      minutes = minutes >= 60 ? 1 : minutes + 1;
      proactiveIntervalMs = minutes * 60UL * 1000;
      prefs.putUInt("pro_min", minutes);
      break;
    default:
      inMenu = false;
      resetProactiveTimer();
      avatar.resume();  // 顔タスクを再開
      poseReset();
      say(handsFree ? "せってい ほぞんした。『スタックちゃん』とよんでね" : "せってい ほぞんした");
      return;
  }
  drawMenuPanel();
}

// 自発発話。予算を使わないよう定型文をローテーションで話し、表情も変える。
void proactiveTick() {
  if (!proactiveOn || inMenu) return;
  if (millis() - lastProactiveMs < proactiveIntervalMs) return;
  lastProactiveMs = millis();
  // 気まぐれ: まれに気分が自然変動する（あるとき性格が変わる）。
  if (random(100) < 8) {
    persMood = clampf(persMood + (random(2) ? 0.3f : -0.3f), -1.0f, 1.0f);
    savePersonality();
  }
  static uint8_t i = 0;
  const size_t n = sizeof(kIdleMoods) / sizeof(kIdleMoods[0]);
  // 気分が良ければ明るい台詞を、悪ければ落ち着いた台詞を出やすくする（確率が個性で変わる）。
  size_t idx = i % n;
  if (persMood > 0.4f)
    idx = random(3);  // 前半(明るめ)に寄せる
  else if (persMood < -0.4f)
    idx = 5 + random(n - 5);  // 後半(ねむい/むむっ等)に寄せる
  const IdleMood& m = kIdleMoods[idx];
  emote(m.exp, m.tilt, m.gazeV, m.gazeH);
  say(m.line);
  i++;
}

bool configUsable() {
#ifdef DSV_EXAMPLE_CONFIG
  return false;
#else
  return strlen(DSV_WIFI_SSID) > 0;
#endif
}

}  // namespace
