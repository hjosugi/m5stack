# StackChan公式ファームウェアの再現ビルド

## 方針

[m5stack/StackChan](https://github.com/m5stack/StackChan)の公開ソースを、確認済みコミットで固定してビルドします。上流の指定通りESP-IDF v5.5.4を使い、UI言語だけを日本語にする公開可能なoverlayを重ねます。Wi-Fi、APIキー、サーバーURL等はこのリポジトリへ記録しません。

公開ソースは配布済みファームウェアより遅れる場合があります。ビルド成功を「実機の工場版より新しい」「そのまま安全に更新できる」という根拠にはしません。

## 初回セットアップ

```bash
direnv allow
task stackchan:factory:setup
```

この処理は次を`.local/`へ取得します。

- StackChan `b72b3ede…`
- StackChan-BSP `f7ed40e6…`
- ESP-IDF v5.5.4の実体 `73550728…` とsubmodule
- ESP32-S3用の公式toolchainとPython環境

URLとHEADは[`config/upstream.lock`](../config/upstream.lock)に照合されます。既存checkoutにローカル変更がある場合は上書きせず中止します。

## ビルド

```bash
task stackchan:factory:build
```

処理内容は次の通りです。

1. 未取得の場合、上流`firmware/fetch_repos.py`で6件の依存を取得する。
2. 各refの実体commitを`config/upstream.lock`に照合する。
3. `xiaozhi-esp32`へ上流同梱パッチが適用済みであることを検証する。
4. モーション座標処理のホスト側CMake/CTestを実行する。
5. ESP-IDFでESP32-S3向け量産ファームウェアをビルドする。
6. 生成`sdkconfig`で日本語有効・英語無効を検証する。

成果物は`.local/build/stackchan-factory-ja/`へ生成されます。実機は接続していても操作されません。

## 設定overlay

公開する差分は[`config/stackchan/sdkconfig.defaults.local`](../config/stackchan/sdkconfig.defaults.local)だけです。

```text
CONFIG_LANGUAGE_EN_US=n
CONFIG_LANGUAGE_JA_JP=y
```

ローカルサーバーURL等を変更する場合は、上流checkout内の`firmware/sdkconfig.defaults.local`へ手元だけで追加できます。この場所は上流側でもGit ignoreされます。認証情報をこの公開リポジトリの`config/`へ追加しないでください。

## 書込みを自動化しない理由

- 公開ソースと工場配布版の新旧を断定できない。
- A/B OTAスロット、NVS、assets、coredumpを含む16 MBの配置を保全する必要がある。
- リセット直後や新ファーム起動時にサーボが動く可能性がある。
- 工場版にはAI Agent、アプリ、OTA等、最小Arduinoスケッチにない機能がある。

実験が必要な場合も、先に検証済み全Flashバックアップを作成し、復旧手順を確認します。
