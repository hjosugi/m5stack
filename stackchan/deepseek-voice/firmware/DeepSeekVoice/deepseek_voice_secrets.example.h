#pragma once

// CI用の安全な例。実機用の値はbuild.shが無視対象の
// deepseek_voice_secrets.h へ生成します。ここには実キーを書かないこと。
#define DSV_WIFI_SSID "change-me"
#define DSV_WIFI_PASSWORD "change-me"

// DeepSeek（OpenAI互換・頭脳）。残高はプリペイド式＝チャージ額が上限。
#define DSV_DEEPSEEK_API_KEY "change-me"
#define DSV_DEEPSEEK_HOST "api.deepseek.com"
#define DSV_DEEPSEEK_MODEL "deepseek-chat"

// クラウドSTT（音声→文字）。既定はOpenAI Whisper。
#define DSV_STT_API_KEY "change-me"
#define DSV_STT_HOST "api.openai.com"
#define DSV_STT_MODEL "whisper-1"

// 使いすぎ防止。1か月の目安コスト（USD）。超過で警告表示。
#define DSV_MONTHLY_BUDGET_USD 5.0f

#define DSV_EXAMPLE_CONFIG 1
