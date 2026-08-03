#pragma once

namespace {

// ---- 自己学習（メモリ） -----------------------------------------------------
// SDに会話メモを蓄積し、FACT（明示的に覚えた事）をLLMのsystemに注入する。
// localモード時は host 側(このrepoの .local)へも送って蓄積する。

const char* const kMemPath = "/dsv_mem.txt";  // SD上の学習ファイル
constexpr size_t kMemMaxLines = 80;           // 起動時にこの行数へ切り詰める
constexpr size_t kMemCtxFacts = 6;            // systemに注入するFACT最大数

// host側(このrepo)の学習エンドポイント。localモードのみ送信。失敗は無視。
void memPushHost(const char* kind, const String& text) {
  if (!backendLocal || strlen(SCV_LOCAL_HOST) == 0) return;
  Endpoint ep = {false, SCV_LOCAL_HOST, SCV_LOCAL_STT_PORT, "/memory", "", ""};
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

}  // namespace
