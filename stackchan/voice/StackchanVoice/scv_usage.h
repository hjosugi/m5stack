#pragma once

namespace {

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
  float budget = SCV_MONTHLY_BUDGET_USD;
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

}  // namespace
