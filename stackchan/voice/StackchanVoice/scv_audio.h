#pragma once

namespace {

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
  if (!backendLocal && estimatedCostUsd() > SCV_MONTHLY_BUDGET_USD) {
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

}  // namespace
