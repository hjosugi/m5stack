# StackChan DeepSeek 音声版（テキスト回答）

StackChan (CoreS3) 用。**画面を長押しで話しかける → 音声をSTT → LLM → 回答は画面にテキスト表示**（音声出力なし）。
バックエンドは2プロファイルを持ち、**画面上部タップで cloud ↔ local を即切替**できる。

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
./scripts/flash-deepseek-voice.sh --allow-flash --replace-factory-firmware
```

## 完全ローカル（任意）

PCで OpenAI互換のLLM/STTを起動する:

```sh
task local:up   # Ollama + faster-whisper系サーバの起動を案内
```

起動後、StackChanの `.env` に `LOCAL_HOST=<PCのIP>` を設定して再ビルド・再書込みし、
画面上部タップで LOCAL に切り替える。

## 注意

- 書込みは `scripts/flash-deepseek-voice.sh` の安全ゲート（対象1台固定・全Flashバックアップmarker・
  StackChan置換フラグ）を通過した場合のみ実行される。
- TLSは個人利用のため証明書検証を省略している（`setInsecure`）。
- 単価は概算。改定時は `.ino` の `kPrice*` を更新すること。
