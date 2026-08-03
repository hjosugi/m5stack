#pragma once

namespace {

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

}  // namespace
