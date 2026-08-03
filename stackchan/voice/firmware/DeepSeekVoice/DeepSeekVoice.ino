// StackChan (CoreS3) 音声質問→テキスト回答ファーム。
//
// 顔(M5Stack-Avatar)は常時表示し、テキストは小さな吹き出しに出す（顔は消さない）。
// 操作: 画面を短タップ=話しかける（録音→質問。触った側へ顔を向ける。声が入らなければ「なで」反応）/
//   画面を長押し(700ms)=設定メニュー(パネル)。cloud↔local切替もメニュー内。電源ボタンは通常の電源。
//   メニュー中は 項目をタッチで切替、「とじる」で保存して終了。
// 表示: 回答が長いと吹き出し内を電光掲示板のように横スクロールする。
// 流れ: 録音 → STT(音声→文字) → LLM → 回答を吹き出しに表示（音声出力なし）。
// バックエンドは2プロファイル: cloud(DeepSeek + OpenAI Whisper) と local(PC上のOpenAI互換サーバ)。
// cloud利用分だけusage/コストをNVSへ積算し、$5/月の予算超過を吹き出しで警告する。
// 同一/正規化が一致する質問はSDキャッシュから返し、LLM呼び出しを節約する。
// 自発発話(既定OFF)はメニューでON。予算節約のため定型文をローテーションで話す。

#include <ArduinoJson.h>
#include <Avatar.h>
#include <HTTPClient.h>
#include <M5Unified.h>
#include <Preferences.h>
#include <SD.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_system.h>  // esp_random()
#include <mbedtls/sha256.h>

#if __has_include("deepseek_voice_secrets.h")
#include "deepseek_voice_secrets.h"
#else
#include "deepseek_voice_secrets.example.h"
#endif

// 手ふり検知（CoreS3カメラ）。SCCBが内部I2Cと共有で実機調整が要るため既定OFF。
// 実機で確認できたら secrets.h 側で 1 にする。
#ifndef DSV_ENABLE_CAMERA
#define DSV_ENABLE_CAMERA 0
#endif
#if DSV_ENABLE_CAMERA
#include "esp_camera.h"
#endif

using namespace m5avatar;

namespace {

// 録音設定。16kHz mono int16。最長約8秒。
constexpr uint32_t kSampleRate = 16000;
constexpr size_t kMaxSamples = kSampleRate * 8;
constexpr size_t kChunkSamples = 1600;  // 100ms

// 概算単価（USD/1M tokens, STTは USD/分）。改定があれば更新すること。
constexpr float kPriceInPerM = 0.27f;
constexpr float kPriceOutPerM = 1.10f;
constexpr float kPriceSttPerMin = 0.006f;

struct Endpoint {
  bool tls;
  const char* host;
  uint16_t port;
  const char* path;
  const char* key;
  const char* model;
};

const Endpoint kCloudLlm = {true, DSV_CLOUD_LLM_HOST, DSV_CLOUD_LLM_PORT, DSV_CLOUD_LLM_PATH,
                            DSV_CLOUD_LLM_KEY, DSV_CLOUD_LLM_MODEL};
const Endpoint kCloudStt = {true, DSV_CLOUD_STT_HOST, DSV_CLOUD_STT_PORT, DSV_CLOUD_STT_PATH,
                            DSV_CLOUD_STT_KEY, DSV_CLOUD_STT_MODEL};
const Endpoint kLocalLlm = {false, DSV_LOCAL_HOST, DSV_LOCAL_LLM_PORT, DSV_LOCAL_LLM_PATH,
                            DSV_LOCAL_LLM_KEY, DSV_LOCAL_LLM_MODEL};
const Endpoint kLocalStt = {false, DSV_LOCAL_HOST, DSV_LOCAL_STT_PORT, DSV_LOCAL_STT_PATH,
                            DSV_LOCAL_STT_KEY, DSV_LOCAL_STT_MODEL};

Preferences prefs;
Avatar avatar;
String speechBacking;  // Balloonはポインタ参照のため実体を保持する
bool sdReady = false;
bool backendLocal = false;  // 選択中のバックエンド（true=local, false=cloud）

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

// ---- usage / 予算 -----------------------------------------------------------

// 現在の年月キー（NVSにRTCが無い場合は0000固定でも良いが、可能ならNTPで更新）。
uint32_t monthKey() {
  struct tm t;
  if (getLocalTime(&t, 0)) {
    return (t.tm_year + 1900) * 100 + (t.tm_mon + 1);
  }
  return 0;
}

void rolloverIfNeeded() {
  uint32_t cur = monthKey();
  uint32_t saved = prefs.getUInt("month", 0);
  if (cur != 0 && cur != saved) {
    prefs.putUInt("month", cur);
    prefs.putULong("in_tok", 0);
    prefs.putULong("out_tok", 0);
    prefs.putUInt("stt_ms", 0);
  }
}

float estimatedCostUsd() {
  double in_tok = prefs.getULong("in_tok", 0);
  double out_tok = prefs.getULong("out_tok", 0);
  double stt_min = prefs.getUInt("stt_ms", 0) / 60000.0;
  return in_tok / 1e6 * kPriceInPerM + out_tok / 1e6 * kPriceOutPerM + stt_min * kPriceSttPerMin;
}

void addUsage(uint32_t in_tok, uint32_t out_tok, uint32_t stt_ms) {
  rolloverIfNeeded();
  prefs.putULong("in_tok", prefs.getULong("in_tok", 0) + in_tok);
  prefs.putULong("out_tok", prefs.getULong("out_tok", 0) + out_tok);
  prefs.putUInt("stt_ms", prefs.getUInt("stt_ms", 0) + stt_ms);
}

void showUsage() {
  rolloverIfNeeded();
  float cost = estimatedCostUsd();
  float budget = DSV_MONTHLY_BUDGET_USD;
  char buf[256];
  snprintf(buf, sizeof(buf),
           "今月の使用量\n入力: %lu tok\n出力: %lu tok\nSTT: %.1f 分\n概算: $%.4f / $%.2f",
           prefs.getULong("in_tok", 0), prefs.getULong("out_tok", 0),
           prefs.getUInt("stt_ms", 0) / 60000.0f, cost, budget);
  showStatus(buf, cost > budget ? TFT_RED : TFT_GREEN);
}

bool isUsageQuery(const String& q) {
  String s = q;
  s.toLowerCase();
  return s.indexOf("usage") >= 0 || q.indexOf("使用量") >= 0 || q.indexOf("いくら") >= 0 ||
         q.indexOf("残高") >= 0;
}

// ---- SDキャッシュ -----------------------------------------------------------

String normalizeQuestion(const String& q) {
  String out;
  for (size_t i = 0; i < q.length(); ++i) {
    char c = q[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '?' || c == 0x3f) continue;
    if (c >= 'A' && c <= 'Z') c = c - 'A' + 'a';
    out += c;
  }
  return out;
}

String cachePath(const String& norm) {
  uint8_t hash[32];
  mbedtls_sha256_context ctx;
  mbedtls_sha256_init(&ctx);
  mbedtls_sha256_starts(&ctx, 0);
  mbedtls_sha256_update(&ctx, reinterpret_cast<const uint8_t*>(norm.c_str()), norm.length());
  mbedtls_sha256_finish(&ctx, hash);
  mbedtls_sha256_free(&ctx);
  char name[80];
  int n = snprintf(name, sizeof(name), "/cache/");
  for (int i = 0; i < 16; ++i) n += snprintf(name + n, sizeof(name) - n, "%02x", hash[i]);
  snprintf(name + n, sizeof(name) - n, ".txt");
  return String(name);
}

bool cacheGet(const String& norm, String& answer) {
  if (!sdReady) return false;
  File f = SD.open(cachePath(norm), FILE_READ);
  if (!f) return false;
  answer = f.readString();
  f.close();
  return answer.length() > 0;
}

void cachePut(const String& norm, const String& answer) {
  if (!sdReady) return;
  if (!SD.exists("/cache")) SD.mkdir("/cache");
  File f = SD.open(cachePath(norm), FILE_WRITE);
  if (!f) return;
  f.print(answer);
  f.close();
}

// ---- HTTP -------------------------------------------------------------------

String buildUrl(const Endpoint& ep) {
  String url = ep.tls ? "https://" : "http://";
  url += ep.host;
  url += ":";
  url += String(ep.port);
  url += ep.path;
  return url;
}

// 生バイトをPOSTし本文を返す。戻り値がHTTPステータス。
int httpPost(const Endpoint& ep, const char* contentType, const uint8_t* body, size_t len,
             String& out) {
  HTTPClient http;
  int status = -1;
  // ローカルはCPU推論で初回が遅い（モデル読込）ため長めに待つ。
  const uint16_t timeoutMs = ep.tls ? 30000 : 90000;
  if (ep.tls) {
    WiFiClientSecure client;
    client.setInsecure();  // 個人利用: 証明書検証を省略
    if (!http.begin(client, buildUrl(ep))) return -1;
    http.setTimeout(timeoutMs);
    if (strlen(ep.key) > 0) http.addHeader("Authorization", String("Bearer ") + ep.key);
    http.addHeader("Content-Type", contentType);
    status = http.POST(const_cast<uint8_t*>(body), len);
    if (status > 0) out = http.getString();
    http.end();
  } else {
    WiFiClient client;
    if (!http.begin(client, buildUrl(ep))) return -1;
    http.setTimeout(timeoutMs);
    if (strlen(ep.key) > 0) http.addHeader("Authorization", String("Bearer ") + ep.key);
    http.addHeader("Content-Type", contentType);
    status = http.POST(const_cast<uint8_t*>(body), len);
    if (status > 0) out = http.getString();
    http.end();
  }
  return status;
}

// ---- 自己学習（メモリ） -----------------------------------------------------
// SDに会話メモを蓄積し、FACT（明示的に覚えた事）をLLMのsystemに注入する。
// localモード時は host 側(このrepoの .local)へも送って蓄積する。

const char* const kMemPath = "/dsv_mem.txt";  // SD上の学習ファイル
constexpr size_t kMemMaxLines = 80;           // 起動時にこの行数へ切り詰める
constexpr size_t kMemCtxFacts = 6;            // systemに注入するFACT最大数

// host側(このrepo)の学習エンドポイント。localモードのみ送信。失敗は無視。
void memPushHost(const char* kind, const String& text) {
  if (!backendLocal || strlen(DSV_LOCAL_HOST) == 0) return;
  Endpoint ep = {false, DSV_LOCAL_HOST, DSV_LOCAL_STT_PORT, "/memory", "", ""};
  JsonDocument d;
  d["kind"] = kind;
  d["text"] = text;
  String body;
  serializeJson(d, body);
  String resp;
  httpPost(ep, "application/json", reinterpret_cast<const uint8_t*>(body.c_str()), body.length(),
           resp);
}

void memAppendSd(const String& line) {
  if (!sdReady) return;
  File f = SD.open(kMemPath, FILE_APPEND);
  if (!f) return;
  f.println(line);
  f.close();
}

// 明示的に覚えた事。FACT行はsystemへ注入され、host側にも送る。
void memRemember(const String& fact) {
  memAppendSd(String("FACT\t") + fact);
  memPushHost("fact", fact);
}

// 通常の質問応答も履歴として残す（host側の自己学習データになる）。
void memLog(const String& q, const String& a) {
  memAppendSd(String("QA\t") + q + "\t" + a);
  memPushHost("qa", q + " => " + a);
}

// 末尾のFACTを集めてsystem注入用の短い文字列を作る。無ければ空。
String memContext() {
  if (!sdReady) return "";
  File f = SD.open(kMemPath, FILE_READ);
  if (!f) return "";
  String facts[kMemCtxFacts];
  size_t cnt = 0;
  while (f.available()) {
    String ln = f.readStringUntil('\n');
    ln.trim();
    if (!ln.startsWith("FACT\t")) continue;
    String fact = ln.substring(5);
    if (fact.length() == 0) continue;
    if (cnt < kMemCtxFacts) {
      facts[cnt++] = fact;
    } else {  // 最新kMemCtxFacts件だけ残すリング
      for (size_t i = 1; i < kMemCtxFacts; ++i) facts[i - 1] = facts[i];
      facts[kMemCtxFacts - 1] = fact;
    }
  }
  f.close();
  if (cnt == 0) return "";
  String ctx = "しっていること:";
  for (size_t i = 0; i < cnt; ++i) ctx += String(" ・") + facts[i];
  return ctx;
}

// 起動時にファイルを末尾kMemMaxLines行へ切り詰める（無制限な肥大化を防ぐ）。
void memTrim() {
  if (!sdReady || !SD.exists(kMemPath)) return;
  File f = SD.open(kMemPath, FILE_READ);
  if (!f) return;
  String ring[kMemMaxLines];
  size_t cnt = 0, head = 0;
  bool over = false;
  while (f.available()) {
    String ln = f.readStringUntil('\n');
    ln.trim();
    if (ln.length() == 0) continue;
    ring[head] = ln;
    head = (head + 1) % kMemMaxLines;
    if (cnt < kMemMaxLines) cnt++;
    else over = true;
  }
  f.close();
  if (!over) return;  // 上限内ならそのまま
  File w = SD.open(kMemPath, FILE_WRITE);
  if (!w) return;
  size_t start = head;  // overのとき head が最古の位置
  for (size_t i = 0; i < cnt; ++i) w.println(ring[(start + i) % kMemMaxLines]);
  w.close();
}

// 「おぼえて/覚えて/メモして」を含めば、その内容をFACTとして保存する。
bool tryRemember(const String& q) {
  if (q.indexOf("おぼえて") < 0 && q.indexOf("覚えて") < 0 && q.indexOf("メモして") < 0 &&
      q.indexOf("めもして") < 0) {
    return false;
  }
  String fact = q;
  fact.replace("おぼえて", "");
  fact.replace("覚えて", "");
  fact.replace("メモして", "");
  fact.replace("めもして", "");
  fact.replace("って", "");
  fact.trim();
  if (fact.length() == 0) fact = q;
  memRemember(fact);
  return true;
}

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

// ---- 音声処理 ---------------------------------------------------------------

int16_t* recBuffer = nullptr;

// 1チャンクのRMS（無音判定用）。
double chunkRms(const int16_t* p, size_t n) {
  uint64_t sum = 0;
  for (size_t i = 0; i < n; i++) {
    int32_t v = p[i];
    sum += static_cast<uint64_t>(v * v);
  }
  return sqrt(static_cast<double>(sum) / n);
}

constexpr double kVadThreshold = 550.0;  // 無音/発話の境界（実機で調整）

// 一発話を録音。話し始めを待ち、末尾の無音約1秒で自動停止する（タップして話す）。
// announce=false は無告知（ハンズフリーの常時listen用）。声が無ければ0を返す。
size_t recordUtterance(bool announce) {
  size_t total = 0;
  M5.Speaker.end();
  M5.Mic.begin();
  if (announce) {
    moodListening();
    say("どうぞ…");
  }
  bool heard = false;
  uint32_t silentMs = 0;
  uint32_t waitedMs = 0;
  const uint32_t chunkMs = kChunkSamples * 1000 / kSampleRate;
  while (total + kChunkSamples <= kMaxSamples) {
    if (!M5.Mic.record(recBuffer + total, kChunkSamples, kSampleRate)) break;
    while (M5.Mic.isRecording()) delay(1);
    double rms = chunkRms(recBuffer + total, kChunkSamples);
    total += kChunkSamples;
    if (rms > kVadThreshold) {
      heard = true;
      silentMs = 0;
    } else if (heard) {
      silentMs += chunkMs;
      if (silentMs > 1000) break;  // 末尾無音1秒で確定
    } else {
      waitedMs += chunkMs;
      if (waitedMs > 4000) break;  // 4秒話し始めなければ諦める
    }
    M5.update();
  }
  M5.Mic.end();
  return heard ? total : 0;
}

// PCMをWAV(16bit mono)へ包む。bufは呼び出し側がps_mallocで確保。
size_t wrapWav(const int16_t* pcm, size_t samples, uint8_t* buf) {
  const uint32_t dataBytes = samples * 2;
  const uint32_t sr = kSampleRate;
  uint32_t p = 0;
  auto put32 = [&](uint32_t v) {
    buf[p++] = v;
    buf[p++] = v >> 8;
    buf[p++] = v >> 16;
    buf[p++] = v >> 24;
  };
  auto put16 = [&](uint16_t v) {
    buf[p++] = v;
    buf[p++] = v >> 8;
  };
  memcpy(buf + p, "RIFF", 4); p += 4;
  put32(36 + dataBytes);
  memcpy(buf + p, "WAVE", 4); p += 4;
  memcpy(buf + p, "fmt ", 4); p += 4;
  put32(16); put16(1); put16(1);
  put32(sr); put32(sr * 2); put16(2); put16(16);
  memcpy(buf + p, "data", 4); p += 4;
  put32(dataBytes);
  memcpy(buf + p, pcm, dataBytes);
  p += dataBytes;
  return p;
}

// STT: WAVをmultipartでPOSTし、書き起こしテキストを返す。
bool transcribe(const int16_t* pcm, size_t samples, uint32_t sttMs, String& text) {
  const Endpoint& ep = backendLocal ? kLocalStt : kCloudStt;
  const size_t wavLen = 44 + samples * 2;
  uint8_t* wav = static_cast<uint8_t*>(ps_malloc(wavLen));
  if (!wav) return false;
  wrapWav(pcm, samples, wav);

  String boundary = "----m5dsv" + String(millis());
  String head = "--" + boundary + "\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n" +
                ep.model + "\r\n--" + boundary +
                "\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\ntext\r\n--" +
                boundary +
                "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.wav\"\r\n"
                "Content-Type: audio/wav\r\n\r\n";
  String tail = "\r\n--" + boundary + "--\r\n";

  size_t bodyLen = head.length() + wavLen + tail.length();
  uint8_t* body = static_cast<uint8_t*>(ps_malloc(bodyLen));
  if (!body) { free(wav); return false; }
  size_t p = 0;
  memcpy(body + p, head.c_str(), head.length()); p += head.length();
  memcpy(body + p, wav, wavLen); p += wavLen;
  memcpy(body + p, tail.c_str(), tail.length()); p += tail.length();
  free(wav);

  String resp;
  int status = httpPost(ep, (String("multipart/form-data; boundary=") + boundary).c_str(), body,
                        bodyLen, resp);
  free(body);
  if (status != 200) {
    if (backendLocal && status <= 0)
      showStatus("STTに つながらない。PCで task stackchan:local:up してね", TFT_RED);
    else
      showStatus((String("STTエラー: ") + status + (backendLocal ? " (local)" : " (cloud)")).c_str(),
                 TFT_RED);
    return false;
  }
  // response_format=text はプレーンテキスト。JSONで返るサーバもあるので両対応。
  resp.trim();
  if (resp.startsWith("{")) {
    JsonDocument doc;
    if (!deserializeJson(doc, resp)) text = doc["text"].as<String>();
  } else {
    text = resp;
  }
  if (!backendLocal) addUsage(0, 0, sttMs);
  return text.length() > 0;
}

// LLM: OpenAI互換 chat/completions。回答テキストを返しusageを積算。
bool askLlm(const String& question, String& answer) {
  const Endpoint& ep = backendLocal ? kLocalLlm : kCloudLlm;
  JsonDocument req;
  req["model"] = ep.model;
  req["stream"] = false;
  req["max_tokens"] = 512;
  JsonArray msgs = req["messages"].to<JsonArray>();
  JsonObject sys = msgs.add<JsonObject>();
  sys["role"] = "system";
  String sysText =
      "あなたはStackChanという小さな卓上ロボットです。げんきで すこし おっちょこちょい、"
      "あいてを おうえんする やさしい せいかく。かんじを つかわず、カタカナと ひらがなだけで、"
      "3ぶんいないで みじかく こたえてね。";
  String mem = memContext();  // 覚えた事があればsystemに注入（自己学習）
  if (mem.length() > 0) sysText += String("\n") + mem;
  // 個性・感性を注入（気分で返事のトーンが変わる）。
  sysText += String("\nいまの きぶん: ") + moodLabel() + "。テンション: " + energyLabel() +
             "。きぶんを へんじに そっと にじませてね。";
  sys["content"] = sysText;
  JsonObject um = msgs.add<JsonObject>();
  um["role"] = "user";
  um["content"] = question;

  String bodyStr;
  serializeJson(req, bodyStr);
  String resp;
  int status = httpPost(ep, "application/json",
                        reinterpret_cast<const uint8_t*>(bodyStr.c_str()), bodyStr.length(), resp);
  if (status != 200) {
    if (backendLocal && status <= 0)
      showStatus("LLMに つながらない。PCで task stackchan:local:up してね", TFT_RED);
    else
      showStatus((String("LLMエラー: ") + status + (backendLocal ? " (local)" : " (cloud)")).c_str(),
                 TFT_RED);
    return false;
  }
  JsonDocument doc;
  if (deserializeJson(doc, resp)) {
    showStatus("応答の解析に失敗", TFT_RED);
    return false;
  }
  answer = doc["choices"][0]["message"]["content"].as<String>();
  if (!backendLocal) {
    uint32_t in_tok = doc["usage"]["prompt_tokens"] | 0;
    uint32_t out_tok = doc["usage"]["completion_tokens"] | 0;
    addUsage(in_tok, out_tok, 0);
  }
  return answer.length() > 0;
}

// 呼びかけ語（スタックちゃん）を含むか。ハンズフリーで会話を始める合図。
bool containsWake(const String& t) {
  String s = t;
  s.toLowerCase();
  return s.indexOf("stack") >= 0 || t.indexOf("スタック") >= 0 || t.indexOf("すたっく") >= 0 ||
         t.indexOf("すたっぷ") >= 0 || t.indexOf("スタッフ") >= 0;
}

// 録音済みサンプルを STT→(必要なら呼びかけ判定)→LLM→吹き出し表示。表情も切り替える。
void processSamples(size_t samples, bool requireWake) {
  uint32_t sttMs = samples * 1000 / kSampleRate;
  moodThinking();
  String question;
  if (!transcribe(recBuffer, samples, sttMs, question)) {
    moodSad();
    return;
  }
  if (requireWake && !containsWake(question)) return;  // 呼びかけでなければLLMを呼ばない

  if (isUsageQuery(question)) {
    showUsage();
    return;
  }
  if (tryRemember(question)) {  // 「おぼえて…」→FACTとして明示学習
    moodHappy();
    nod(1);
    say("おぼえたよ！");
    return;
  }
  learnFromUtterance(question);  // 基本は毎回学習（気分・感性を更新）
  String norm = normalizeQuestion(question);
  String answer;
  if (cacheGet(norm, answer)) {
    moodByPersonality();
    showAnswer(question, answer, true);
    return;
  }
  moodThinking();
  say(String("かんがえ中…(") + (backendLocal ? "local" : "cloud") + ")");
  if (!askLlm(question, answer)) {
    moodSad();
    return;
  }
  cachePut(norm, answer);
  memLog(question, answer);  // 自己学習: 履歴を蓄積（localならhostへも）
  moodByPersonality();
  nod(1);
  if (!backendLocal && estimatedCostUsd() > DSV_MONTHLY_BUDGET_USD) {
    say(answer + " ［予算超過］");
  } else {
    showAnswer(question, answer, false);
  }
}

// 画面タップ=話す。少し待って声を録り、無音で自動確定。
void handleInteraction() {
  size_t samples = recordUtterance(true);
  if (samples < kSampleRate / 3) {
    // 声が入らなければ静かに待機へ戻す（会話とかぶるので反応は出さない）。
    poseReset();
    say("");
    return;
  }
  processSamples(samples, false);
}

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

void setup() {
  auto cfg = M5.config();
  cfg.internal_mic = true;
  cfg.internal_spk = false;  // 音声出力は使わない
  M5.begin(cfg);
  M5.Display.setRotation(1);
  Serial.begin(115200);

  // StackChanの顔を起動（別タスクで常時描画）。テキストは小さな吹き出しに出す。
  avatar.init();
  avatar.setSpeechFont(&fonts::lgfxJapanGothic_12);  // 少し大きめ（吹き出しはBalloon側で小さく）
  poseReset();

  recBuffer = static_cast<int16_t*>(ps_malloc(kMaxSamples * sizeof(int16_t)));
  prefs.begin("dsv", false);
  loadSettings();
  loadPersonality();
  randomSeed(esp_random());  // 気まぐれ用の乱数を実機ごとにばらす

  if (!configUsable()) {
    showStatus("設定が必要です。build.shで生成してください。", TFT_RED);
    return;
  }

  showStatus("Wi-Fi接続中…");
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(DSV_WIFI_SSID, DSV_WIFI_PASSWORD);
  uint32_t deadline = millis() + 20000;
  while (WiFi.status() != WL_CONNECTED && static_cast<int32_t>(deadline - millis()) > 0) delay(100);
  if (WiFi.status() != WL_CONNECTED) {
    showStatus("Wi-Fi接続に失敗", TFT_RED);
    return;
  }
  configTime(9 * 3600, 0, "ntp.nict.jp", "pool.ntp.org");  // JST。月次リセット判定用

  sdReady = SD.begin();
  memTrim();                        // 学習ファイルを上限行数に整える
  backendLocal = DSV_PREFER_LOCAL;  // 既定モード。実行中は上部タップで切替可。
  say(backendLocal ? "こんにちは（local）。ぼくを タッチして はなしてね。ながおしで せってい。"
                   : "こんにちは（cloud）。ぼくを タッチして はなしてね。ながおしで せってい。");
}

void loop() {
  M5.update();
  proactiveTick();

  // 呼びかけ会話: 待機中は常時listen。声＋『スタックちゃん』で会話開始。
  if (handsFree && !inMenu && M5.Touch.getCount() == 0) {
    size_t s = recordUtterance(false);
    if (s >= kSampleRate / 3) processSamples(s, true);
  }

  if (recBuffer && M5.Touch.getCount() > 0) {
    auto detail = M5.Touch.getDetail();

    if (inMenu) {
      // メニュー中: 触った項目を切替。「とじる」で保存して終了。
      menuIndex = menuRowAt(detail.y);
      menuApply();
    } else {
      // 画面を短タップ=話しかける / 長押し(700ms)=設定メニュー。
      uint32_t pressStart = millis();
      while (M5.Touch.getCount() > 0 && millis() - pressStart < 700) {
        M5.update();
        delay(10);
      }
      if (M5.Touch.getCount() > 0) {
        inMenu = true;
        menuIndex = 0;
        avatar.suspend();  // 顔タスクを止めてパネルを描く
        drawMenuPanel();
      } else {
        // 触った側へ顔を向けて話しかける。
        g_listenGazeH = (160.0f - detail.x) / 160.0f * 0.6f;
        handleInteraction();
      }
    }

    // 誤連打防止: 指を離すまで待つ
    while (M5.Touch.getCount() > 0) {
      M5.update();
      delay(10);
    }
    delay(150);
  }
  delay(10);
}
