#pragma once

namespace {

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

}  // namespace
