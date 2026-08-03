// StackChan (CoreS3) 音声質問→テキスト回答ファーム。
//
// 顔(M5Stack-Avatar)は常時表示し、テキストは小さな吹き出しに出す（顔は消さない）。
// 操作: 画面を短タップ=話しかける（録音→質問。触った側へ顔を向ける。声が入らなければ「なで」反応）/
//   画面を長押し(700ms)=設定メニュー(パネル)。cloud↔local切替もメニュー内。電源ボタンは通常の電源。
//   メニュー中は 項目をタッチで切替、「とじる」で保存して終了。
// 表示: 回答が長いと吹き出し内を電光掲示板のように横スクロールする。
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
#include <esp_system.h>  // esp_random()
#include <mbedtls/sha256.h>

#if __has_include("stackchan_voice_secrets.h")
#include "stackchan_voice_secrets.h"
#else
#include "stackchan_voice_secrets.example.h"
#endif

// 手ふり検知（CoreS3カメラ）。SCCBが内部I2Cと共有で実機調整が要るため既定OFF。
// 実機で確認できたら secrets.h 側で 1 にする。
#ifndef SCV_ENABLE_CAMERA
#define SCV_ENABLE_CAMERA 0
#endif
#if SCV_ENABLE_CAMERA
#include "esp_camera.h"
#endif

using namespace m5avatar;

// 単一translation unitを機能ごとのモジュールヘッダへ分割している。
// 各ヘッダは #pragma once の後、自身を無名namespaceで包む（同一TU内の
// 複数の無名namespaceは同じ名前空間を共有するのでグローバルは相互に見える）。
// 依存順（定義は使用より前）に include すること。
#include "scv_globals.h"       // 定数・Endpoint表・小さなグローバル
#include "scv_display.h"       // say/showStatus/showAnswer と表情・モーション
#include "scv_usage.h"         // usage/予算(NVS)
#include "scv_cache.h"         // SDキャッシュ + SHA
#include "scv_http.h"          // buildUrl/httpPost
#include "scv_memory.h"        // 自己学習メモリ
#include "scv_personality.h"   // 個性・感性（学習）
#include "scv_audio.h"         // 録音・STT・LLM・processSamples
#include "scv_menu.h"          // 設定/自発/メニュー


void setup() {
  auto cfg = M5.config();
  cfg.internal_mic = true;
  cfg.internal_spk = false;  // 音声出力は使わない
  M5.begin(cfg);
  M5.Display.setRotation(1);
  Serial.begin(115200);

  // StackChanの顔を起動（別タスクで常時描画）。テキストは小さな吹き出しに出す。
  avatar.init();
  avatar.setSpeechFont(&fonts::lgfxJapanGothic_12);  // 少し大きめ（吹き出しはBalloon側で小さく）
  poseReset();

  recBuffer = static_cast<int16_t*>(ps_malloc(kMaxSamples * sizeof(int16_t)));
  prefs.begin("dsv", false);
  loadSettings();
  loadPersonality();
  randomSeed(esp_random());  // 気まぐれ用の乱数を実機ごとにばらす

  if (!configUsable()) {
    showStatus("設定が必要です。build.shで生成してください。", TFT_RED);
    return;
  }

  showStatus("Wi-Fi接続中…");
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(SCV_WIFI_SSID, SCV_WIFI_PASSWORD);
  uint32_t deadline = millis() + 20000;
  while (WiFi.status() != WL_CONNECTED && static_cast<int32_t>(deadline - millis()) > 0) delay(100);
  if (WiFi.status() != WL_CONNECTED) {
    showStatus("Wi-Fi接続に失敗", TFT_RED);
    return;
  }
  configTime(9 * 3600, 0, "ntp.nict.jp", "pool.ntp.org");  // JST。月次リセット判定用

  sdReady = SD.begin();
  memTrim();                        // 学習ファイルを上限行数に整える
  backendLocal = SCV_PREFER_LOCAL;  // 既定モード。実行中は上部タップで切替可。
  say(backendLocal ? "こんにちは（local）。ぼくを タッチして はなしてね。ながおしで せってい。"
                   : "こんにちは（cloud）。ぼくを タッチして はなしてね。ながおしで せってい。");
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

    if (inMenu) {
      // メニュー中: 触った項目を切替。「とじる」で保存して終了。
      menuIndex = menuRowAt(detail.y);
      menuApply();
    } else {
      // 画面を短タップ=話しかける / 長押し(700ms)=設定メニュー。
      uint32_t pressStart = millis();
      while (M5.Touch.getCount() > 0 && millis() - pressStart < 700) {
        M5.update();
        delay(10);
      }
      if (M5.Touch.getCount() > 0) {
        inMenu = true;
        menuIndex = 0;
        avatar.suspend();  // 顔タスクを止めてパネルを描く
        drawMenuPanel();
      } else {
        // 触った側へ顔を向けて話しかける。
        g_listenGazeH = (160.0f - detail.x) / 160.0f * 0.6f;
        handleInteraction();
      }
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
