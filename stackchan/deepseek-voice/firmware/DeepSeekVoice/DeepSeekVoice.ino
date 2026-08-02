// StackChan (CoreS3) 音声質問→テキスト回答ファーム。
//
// 流れ: タッチ長押しでマイク録音 → STT(音声→文字) → LLM → 画面にテキスト表示（音声なし）。
// バックエンドは2プロファイル: cloud(DeepSeek + OpenAI Whisper) と local(PC上のOpenAI互換サーバ)。
// PC(=DSV_LOCAL_HOST)が到達可能なら local を自動優先し、落ちていれば cloud へフォールバック。
// cloud利用分だけusage/コストをNVSへ積算し、$5/月の予算超過を画面警告する。
// 同一/正規化が一致する質問はSDキャッシュから返し、LLM呼び出しを節約する。

#include <ArduinoJson.h>
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
bool sdReady = false;
bool backendLocal = false;  // 選択中のバックエンド（true=local, false=cloud）
bool localUp = false;       // localが到達可能か（警告表示用のみ、選択には影響しない）
uint32_t nextLocalProbe = 0;

// ---- 表示ヘルパ -------------------------------------------------------------

void drawHeader() {
  const int w = M5.Display.width();
  M5.Display.fillRect(0, 0, w, 20, TFT_BLACK);
  M5.Display.setFont(&fonts::lgfxJapanGothic_16);
  // local選択かつ到達不可なら赤で警告。cloudは水色。
  M5.Display.setTextColor(backendLocal ? (localUp ? TFT_GREEN : TFT_RED) : TFT_CYAN, TFT_BLACK);
  M5.Display.setCursor(4, 2);
  M5.Display.print(backendLocal ? "LOCAL" : "CLOUD");
  M5.Display.setTextColor(TFT_DARKGREY, TFT_BLACK);
  M5.Display.setCursor(78, 2);
  M5.Display.print("上部タップで切替");
}

void showStatus(const char* text, uint16_t color = TFT_WHITE) {
  M5.Display.fillRect(0, 20, M5.Display.width(), M5.Display.height() - 20, TFT_BLACK);
  drawHeader();
  M5.Display.setFont(&fonts::lgfxJapanGothic_16);
  M5.Display.setTextColor(color, TFT_BLACK);
  M5.Display.setTextWrap(true);
  M5.Display.setCursor(6, 28);
  M5.Display.print(text);
}

void showAnswer(const String& question, const String& answer, bool fromCache) {
  M5.Display.fillScreen(TFT_BLACK);
  drawHeader();
  M5.Display.setFont(&fonts::lgfxJapanGothic_16);
  M5.Display.setTextWrap(true);
  M5.Display.setCursor(6, 24);
  M5.Display.setTextColor(TFT_YELLOW, TFT_BLACK);
  M5.Display.printf("Q: %s\n", question.c_str());
  M5.Display.setTextColor(fromCache ? TFT_LIGHTGREY : TFT_WHITE, TFT_BLACK);
  M5.Display.print(answer);
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

// PCのローカルLLMポートへTCP接続できるか（=完全ローカルへ切替可能か）。
bool probeLocal() {
  if (strlen(DSV_LOCAL_HOST) == 0) return false;  // local未設定なら探索しない
  WiFiClient c;
  bool ok = c.connect(DSV_LOCAL_HOST, DSV_LOCAL_LLM_PORT, 400);
  c.stop();
  return ok;
}

void refreshBackend() {
  if (millis() >= nextLocalProbe) {
    nextLocalProbe = millis() + 3000;
    bool prev = localUp;
    localUp = probeLocal();
    if (prev != localUp) drawHeader();
  }
}

// ---- 音声処理 ---------------------------------------------------------------

int16_t* recBuffer = nullptr;

size_t recordWhileTouched() {
  size_t total = 0;
  M5.Speaker.end();
  M5.Mic.begin();
  showStatus("聞いています… (指を離すと送信)", TFT_ORANGE);
  while (total < kMaxSamples) {
    M5.update();
    if (M5.Touch.getCount() == 0) break;
    size_t chunk = kChunkSamples;
    if (total + chunk > kMaxSamples) chunk = kMaxSamples - total;
    if (!M5.Mic.record(recBuffer + total, chunk, kSampleRate)) break;
    while (M5.Mic.isRecording()) {
      delay(1);
    }
    total += chunk;
  }
  M5.Mic.end();
  return total;
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

void handleInteraction() {
  size_t samples = recordWhileTouched();
  if (samples < kSampleRate / 2) {  // 0.5秒未満は無視
    showStatus("短すぎます。長押しで話しかけてください。", TFT_LIGHTGREY);
    return;
  }
  uint32_t sttMs = samples * 1000 / kSampleRate;
  showStatus("文字起こし中…");
  String question;
  if (!transcribe(recBuffer, samples, sttMs, question)) return;

  if (isUsageQuery(question)) {
    showUsage();
    return;
  }

  String norm = normalizeQuestion(question);
  String answer;
  if (cacheGet(norm, answer)) {
    showAnswer(question, answer, true);
    return;
  }

  showStatus((String("考え中… (") + (backendLocal ? "local" : "cloud") + ")").c_str());
  if (!askLlm(question, answer)) return;
  cachePut(norm, answer);
  showAnswer(question, answer, false);

  if (!backendLocal && estimatedCostUsd() > DSV_MONTHLY_BUDGET_USD) {
    M5.Display.setTextColor(TFT_RED, TFT_BLACK);
    M5.Display.print("\n[予算超過] localへ切替推奨");
  }
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
  M5.Display.fillScreen(TFT_BLACK);

  recBuffer = static_cast<int16_t*>(ps_malloc(kMaxSamples * sizeof(int16_t)));
  prefs.begin("dsv", false);

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
  refreshBackend();
  showStatus("画面を長押しで話しかけてください。\n上部タップでcloud↔local切替。\n『usage教えて』で使用量表示。",
             TFT_WHITE);
}

void loop() {
  M5.update();
  refreshBackend();
  if (recBuffer && M5.Touch.getCount() > 0) {
    auto detail = M5.Touch.getDetail();
    if (detail.y < 20) {
      // 上部タップ: バックエンドを即切替
      backendLocal = !backendLocal;
      drawHeader();
    } else {
      handleInteraction();
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
