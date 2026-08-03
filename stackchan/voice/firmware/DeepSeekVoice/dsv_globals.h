#pragma once

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

}  // namespace
