// StackChan (CoreS3) 音声質問→テキスト回答ファーム。
//
// 顔(M5Stack-Avatar)は常時表示し、テキストは小さな吹き出しに出す（顔は消さない）。
// 操作(タッチ): 顔を長押し=録音して質問 / 顔を短くタップ=なで反応 /
//   上部を短くタップ=cloud↔local切替 / 上部を長押し=設定メニュー。
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
  if (ep.tls) {
    WiFiClientSecure client;
    client.setInsecure();  // 個人利用: 証明書検証を省略
    if (!http.begin(client, buildUrl(ep))) return -1;
    http.setTimeout(30000);
    if (strlen(ep.key) > 0) http.addHeader("Authorization", String("Bearer ") + ep.key);
    http.addHeader("Content-Type", contentType);
    status = http.POST(const_cast<uint8_t*>(body), len);
    if (status > 0) out = http.getString();
    http.end();
  } else {
    WiFiClient client;
    if (!http.begin(client, buildUrl(ep))) return -1;
    http.setTimeout(30000);
    if (strlen(ep.key) > 0) http.addHeader("Authorization", String("Bearer ") + ep.key);
    http.addHeader("Content-Type", contentType);
    status = http.POST(const_cast<uint8_t*>(body), len);
    if (status > 0) out = http.getString();
    http.end();
  }
  return status;
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
    avatar.setExpression(Expression::Neutral);
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
    showStatus((String("STTエラー: ") + status).c_str(), TFT_RED);
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
  sys["content"] = "あなたはStackChanという小さな卓上ロボットです。日本語で簡潔に、3文以内で答えてください。";
  JsonObject um = msgs.add<JsonObject>();
  um["role"] = "user";
  um["content"] = question;

  String bodyStr;
  serializeJson(req, bodyStr);
  String resp;
  int status = httpPost(ep, "application/json",
                        reinterpret_cast<const uint8_t*>(bodyStr.c_str()), bodyStr.length(), resp);
  if (status != 200) {
    showStatus((String("LLMエラー: ") + status).c_str(), TFT_RED);
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
  avatar.setExpression(Expression::Doubt);
  String question;
  if (!transcribe(recBuffer, samples, sttMs, question)) {
    avatar.setExpression(Expression::Sad);
    return;
  }
  if (requireWake && !containsWake(question)) return;  // 呼びかけでなければLLMを呼ばない

  if (isUsageQuery(question)) {
    showUsage();
    return;
  }
  String norm = normalizeQuestion(question);
  String answer;
  if (cacheGet(norm, answer)) {
    avatar.setExpression(Expression::Happy);
    showAnswer(question, answer, true);
    return;
  }
  say(String("考え中…(") + (backendLocal ? "local" : "cloud") + ")");
  if (!askLlm(question, answer)) {
    avatar.setExpression(Expression::Sad);
    return;
  }
  cachePut(norm, answer);
  avatar.setExpression(Expression::Happy);
  if (!backendLocal && estimatedCostUsd() > DSV_MONTHLY_BUDGET_USD) {
    say(answer + " ［予算超過］");
  } else {
    showAnswer(question, answer, false);
  }
}

// 顔をタップ=話す。少し待って声を録り、無音で自動確定。
void handleInteraction() {
  size_t samples = recordUtterance(true);
  if (samples < kSampleRate / 3) {
    avatar.setExpression(Expression::Neutral);
    say("よく聞こえなかったよ");
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

const char* const kIdleLines[] = {"ひまだなぁ", "なにか手伝おうか？", "話しかけてね", "げんきー？",
                                  "ちょっと休憩する？"};

void loadSettings() {
  proactiveOn = prefs.getBool("pro_on", false);
  handsFree = prefs.getBool("hf_on", false);
  uint32_t minutes = prefs.getUInt("pro_min", 5);
  if (minutes < 1) minutes = 1;
  proactiveIntervalMs = minutes * 60UL * 1000;
  lastProactiveMs = millis();
}

void resetProactiveTimer() { lastProactiveMs = millis(); }

void showMenu() {
  uint32_t minutes = proactiveIntervalMs / 60000;
  switch (menuIndex) {
    case 0:
      say(String("設定1/4 会話:") + (handsFree ? "呼びかけ" : "手動(タッチ)") + " 下=切替/上=次");
      break;
    case 1: say(String("設定2/4 自発:") + (proactiveOn ? "ON" : "OFF") + " 下=切替/上=次"); break;
    case 2: say(String("設定3/4 自発間隔:") + minutes + "分 下=+1/上=次"); break;
    default: say("設定4/4 下=閉じる/上=次"); break;
  }
}

void menuNext() {
  menuIndex = (menuIndex + 1) % 4;
  showMenu();
}

void menuChange() {
  uint32_t minutes = proactiveIntervalMs / 60000;
  switch (menuIndex) {
    case 0:
      handsFree = !handsFree;
      prefs.putBool("hf_on", handsFree);
      break;
    case 1:
      proactiveOn = !proactiveOn;
      prefs.putBool("pro_on", proactiveOn);
      break;
    case 2:
      minutes = minutes >= 60 ? 1 : minutes + 1;
      proactiveIntervalMs = minutes * 60UL * 1000;
      prefs.putUInt("pro_min", minutes);
      break;
    default:
      inMenu = false;
      resetProactiveTimer();
      say(handsFree ? "設定を閉じた。『スタックちゃん』と呼んでね" : "設定を閉じた");
      return;
  }
  showMenu();
}

// 自発発話。予算を使わないよう定型文をローテーションで話し、表情も変える。
void proactiveTick() {
  if (!proactiveOn || inMenu) return;
  if (millis() - lastProactiveMs < proactiveIntervalMs) return;
  lastProactiveMs = millis();
  static uint8_t i = 0;
  const Expression moods[] = {Expression::Happy, Expression::Doubt, Expression::Sleepy};
  avatar.setExpression(moods[i % 3]);
  say(kIdleLines[i % (sizeof(kIdleLines) / sizeof(kIdleLines[0]))]);
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
  avatar.setSpeechFont(&fonts::lgfxJapanGothic_12);

  recBuffer = static_cast<int16_t*>(ps_malloc(kMaxSamples * sizeof(int16_t)));
  prefs.begin("dsv", false);
  loadSettings();

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
  backendLocal = DSV_PREFER_LOCAL;  // 既定モード。実行中は上部タップで切替可。
  say(backendLocal ? "こんにちは（local）。長押しで話しかけてね。"
                   : "こんにちは（cloud）。長押しで話しかけてね。");
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
    bool top = detail.y < 20;

    if (inMenu) {
      // メニュー中: 上=次の項目 / 下=値を変更
      if (top) menuNext();
      else menuChange();
    } else if (top) {
      // 上部: 短タップ=cloud/local切替、長押し=設定メニュー
      uint32_t pressStart = millis();
      while (M5.Touch.getCount() > 0 && millis() - pressStart < 700) {
        M5.update();
        delay(10);
      }
      if (M5.Touch.getCount() > 0) {
        inMenu = true;
        menuIndex = 0;
        showMenu();
      } else {
        backendLocal = !backendLocal;
        say(backendLocal ? "ローカルに切替" : "クラウドに切替");
      }
    } else {
      handleInteraction();  // 顔をさわる=話しかける（タップして話す）
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
