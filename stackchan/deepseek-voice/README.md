# StackChan DeepSeek 音声版（テキスト回答）

StackChan (CoreS3) 用。**顔(M5Stack-Avatar)は常時表示**し、**回答は小さな吹き出し**に出す（顔は消さない）。
音声で質問 → STT → LLM → 吹き出しにテキスト表示（音声出力なし）。バックエンドは cloud / local の2プロファイル。

## 操作（タッチ）

| 操作 | 動作 |
| --- | --- |
| 顔を長押し | 録音して質問（離すと送信） |
| 顔を短くタップ | なで反応（定型・無料） |
| 上部を短くタップ | cloud ↔ local 切替 |
| 上部を長押し | 設定メニュー（自発ON/OFF・間隔・なで反応。上=次/下=変更） |
| 「usage教えて」と発話 | 今月の使用量・概算コストを表示 |

自発発話（5分ごと等）は**既定OFF**。メニューでONにでき、予算節約のため定型文をローテーションで話す。

| モード | STT | LLM | コスト |
| --- | --- | --- | --- |
| cloud | OpenAI Whisper | DeepSeek | プリペイド残高から従量。$5/月の予算を画面警告 |
| local | PC上のOpenAI互換STT | PC上のOllama等 | 無料（PC起動が前提） |

- 使用量: cloud利用分のtoken/STT秒をNVSに積算。`usage教えて`と話すと今月の概算コストを表示。
- 節約: 正規化した質問をSDにキャッシュし、一致すればLLMを呼ばない。
- 秘密情報: WiFi/APIキーは `stackchan/deepseek-voice/.env`（Git管理外）に置き、build.shが `deepseek_voice_secrets.h` を生成する。

## 使い方

```sh
# 1) 設定（実キーはこのファイルのみ。Git管理されない）
cp stackchan/deepseek-voice/.env.example stackchan/deepseek-voice/.env
#   DEEPSEEK_API / STT_API_KEY を設定
#   Wi-Fiは task wifi でPCの現在の接続から取り込める（確認あり）:
task wifi
#   完全ローカルも使うなら PREFER_LOCAL / LOCAL_HOST 等も設定

# 2) ビルド（書込みなし）
task deepseek:build
# 例ヘッダだけで疎通確認するなら: task deepseek:build:ci

# 3) 書込み（StackChanを1台に固定し、全Flashバックアップ確保後）
task device:init && task device:select MODEL=stackchan
task device:grant
./stackchan/deepseek-voice/flash.sh --allow-flash --replace-factory-firmware
```

## 完全ローカル（任意）

PCで OpenAI互換のLLM/STTを起動する:

```sh
task local:up   # Ollama + faster-whisper系サーバの起動を案内
```

起動後、StackChanの `.env` に `LOCAL_HOST=<PCのIP>` を設定して再ビルド・再書込みし、
画面上部タップで LOCAL に切り替える。

## 注意

- 書込みは `stackchan/deepseek-voice/flash.sh` の安全ゲート（対象1台固定・全Flashバックアップmarker・
  StackChan置換フラグ）を通過した場合のみ実行される。
- TLSは個人利用のため証明書検証を省略している（`setInsecure`）。
- 単価は概算。改定時は `.ino` の `kPrice*` を更新すること。
