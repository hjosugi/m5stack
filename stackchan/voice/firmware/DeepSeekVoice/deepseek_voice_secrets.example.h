#pragma once

// CI用の安全な例。実機用の値はbuild.shが無視対象の
// deepseek_voice_secrets.h へ生成します。ここには実キーを書かないこと。

#define DSV_WIFI_SSID "change-me"
#define DSV_WIFI_PASSWORD "change-me"

// cloudプロファイル: DeepSeek(頭脳) + OpenAI Whisper(STT)。
#define DSV_CLOUD_LLM_HOST "api.deepseek.com"
#define DSV_CLOUD_LLM_PORT 443
#define DSV_CLOUD_LLM_PATH "/chat/completions"
#define DSV_CLOUD_LLM_KEY "change-me"
#define DSV_CLOUD_LLM_MODEL "deepseek-chat"

#define DSV_CLOUD_STT_HOST "api.openai.com"
#define DSV_CLOUD_STT_PORT 443
#define DSV_CLOUD_STT_PATH "/v1/audio/transcriptions"
#define DSV_CLOUD_STT_KEY "change-me"
#define DSV_CLOUD_STT_MODEL "whisper-1"

// localプロファイル: PC上のOpenAI互換サーバ（Ollama + whisperサーバ等）。
#define DSV_LOCAL_HOST "192.0.2.2"
#define DSV_LOCAL_LLM_PORT 11434
#define DSV_LOCAL_LLM_PATH "/v1/chat/completions"
#define DSV_LOCAL_LLM_KEY "ollama"
#define DSV_LOCAL_LLM_MODEL "qwen2.5:3b"

#define DSV_LOCAL_STT_PORT 8000
#define DSV_LOCAL_STT_PATH "/v1/audio/transcriptions"
#define DSV_LOCAL_STT_KEY ""
#define DSV_LOCAL_STT_MODEL "Systran/faster-whisper-small"

// PCが到達可能なら完全ローカルへ自動切替（1=有効）。
#define DSV_PREFER_LOCAL 1

// 使いすぎ防止。1か月の目安コスト（USD）。cloud利用分のみ課金。
#define DSV_MONTHLY_BUDGET_USD 5.0f

#define DSV_EXAMPLE_CONFIG 1
