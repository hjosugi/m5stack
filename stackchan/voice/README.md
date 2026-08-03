# StackChan 音声版（テキスト回答）

StackChan (CoreS3) 用。**顔(M5Stack-Avatar)は常時表示**し、**回答は小さな吹き出し**に出す（顔は消さない）。
音声で質問 → STT → LLM → 吹き出しにテキスト表示（音声出力なし）。バックエンドは cloud / local の2プロファイル。

## 操作

| 操作 | 動作 |
| --- | --- |
| **画面を短タップ** | 話しかける。触った側へ顔を向け、録音→末尾の無音で自動確定→回答 |
| 「スタックちゃん」と呼ぶ | 呼びかけモードON時、声だけで会話開始（常時listen） |
| **画面を長押し（700ms）** | 設定メニュー（**パネル表示**。項目をタッチで切替、「とじる」で保存） |
| （電源ボタン） | 通常の電源（本ファームでは使用しない） |
| 「◯◯っておぼえて」と発話 | その内容をFACTとして記憶（以後の返答に反映） |
| 「usage教えて」と発話 | 今月の使用量・概算コスト |

- 設定メニュー項目：**モード（cloud↔local）** / 会話（タッチ/呼びかけ）/ 自発ON・OFF / 自発間隔 / とじる。
- **会話モード**（手動タッチ / 呼びかけ）と**自発発話**は既定OFF。メニューでON。
- 回答が長いと吹き出し内を**電光掲示板のように横スクロール**して読める。
- 表情・動きが豊か：考え中は上を見て首かしげ、回答はうなずき、なで反応、自発は気分で台詞と首の角度が変化。
- **自己学習**：会話は基本すべて記憶。`mood/energy/curiosity`（NVS保存）を会話から学習し、返事のトーンと表情の出やすさに反映（まれに気まぐれ変動）。localモード時は host 側 `.local/memory/dsv-memory.jsonl` にも蓄積。
- 返事は**カタカナ・ひらがなのみ**（小さい画面で読みやすく）。
- 呼びかけモードは常時STTするため、cloudだとSTT費用が増える。localなら無料。
- 今後の予定・既知の制約（声の方向/カメラ/ブラウザ設定GUIなど）は [ROADMAP.md](ROADMAP.md)。

| モード | STT | LLM | コスト |
| --- | --- | --- | --- |
| cloud | OpenAI Whisper | DeepSeek | プリペイド残高から従量。$5/月の予算を画面警告 |
| local | PC上のOpenAI互換STT | PC上のOllama等 | 無料（PC起動が前提） |

- 使用量: cloud利用分のtoken/STT秒をNVSに積算。`usage教えて`と話すと今月の概算コストを表示。
- 節約: 正規化した質問をSDにキャッシュし、一致すればLLMを呼ばない。
- 秘密情報: WiFi/APIキーは `stackchan/voice/.env`（Git管理外）に置き、build.shが `deepseek_voice_secrets.h` を生成する。

## 使い方

```sh
# 1) 設定（実キーはこのファイルのみ。Git管理されない）
cp stackchan/voice/.env.example stackchan/voice/.env
#   DEEPSEEK_API / STT_API_KEY を設定
#   Wi-Fiは task wifi でPCの現在の接続から取り込める（確認あり）:
task wifi
#   完全ローカルも使うなら PREFER_LOCAL / LOCAL_HOST 等も設定

# 2) ビルド（書込みなし）
task stackchan:build
# 例ヘッダだけで疎通確認するなら: task stackchan:build:ci

# 3) 書込み（StackChanを1台に固定し、全Flashバックアップ確保後）
task device:init && task device:select MODEL=stackchan
task device:grant
./stackchan/voice/flash.sh --allow-flash --replace-factory-firmware
```

## 完全ローカル（任意）

PCで OpenAI互換のLLM/STTを起動する:

```sh
task stackchan:local:up       # Ollama + faster-whisper系サーバを起動
task stackchan:local:status   # 稼働状態を確認（OK/NG）
```

起動後、StackChanの `.env` に `LOCAL_HOST=<PCのIP>` を設定して再ビルド・再書込みし、
**画面長押し→設定メニューの「モード」** で local に切り替える（`PREFER_LOCAL=1` なら起動時からLOCAL）。

## 注意

- 書込みは `stackchan/voice/flash.sh` の安全ゲート（対象1台固定・全Flashバックアップmarker・
  StackChan置換フラグ）を通過した場合のみ実行される。
- TLSは個人利用のため証明書検証を省略している（`setInsecure`）。
- 単価は概算。改定時は `.ino` の `kPrice*` を更新すること。
