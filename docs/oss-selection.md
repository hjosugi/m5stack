# OSSとバージョンの選定

調査日は2026-07-31です。バージョン番号だけでなく、ビルドに使うGitコミットも[`config/upstream.lock`](../config/upstream.lock)に固定しています。

## Arduino経路

| 要素 | 固定版 | 選定理由 |
| --- | --- | --- |
| Arduino CLI | 1.5.1 | 再現可能な非GUIビルドとCI |
| M5Stack Arduino Core | 3.3.8 | [M5Stack公式Board Manager索引](https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json)の安定版 |
| M5Unified | 0.2.19 | 製品横断の公式ハードウェアAPI |
| M5GFX | 0.2.26 | M5Unifiedが利用する公式描画基盤 |
| M5Cardputer | 1.1.1 | Cardputer / Cardputer Adv用 |
| StackChan-BSP | 1.1.0 + commit固定 | StackChan本体のArduino BSP |
| IRremoteESP8266 | 2.9.0 | StackChan-BSPの明示依存 |
| M5Unit-NFC | 0.1.0 | StackChan-BSPの明示依存 |

Espressif汎用Arduino Coreの最新版とM5Stack公式索引の版は一致するとは限りません。本リポジトリでは、M5Stack固有のFQBNと配布物を含む公式索引の3.3.8を採用します。

Arduino Library Managerの`M5StackChan`は調査時点で1.0.1でした。一方、[StackChan-BSP公式リポジトリ](https://github.com/m5stack/StackChan-BSP)の`library.properties`は1.1.0です。未公開の移動する`main`を直接使わず、確認した1.1.0のコミット`f7ed40e6…`を固定checkoutします。

## 公式ファームウェア経路

| 要素 | 固定値 | 根拠 |
| --- | --- | --- |
| StackChanソース | `b72b3ede…` | 2026-07-31時点の公式`main` |
| ファームウェア版 | 1.4.3 | 上記ソースの`firmware/CMakeLists.txt` |
| ESP-IDF | v5.5.4 / `73550728…` | 上流`firmware/README.md`の指定 |
| 外部依存6件 | commit固定 | 上流`repos.json`のrefを解決して固定 |

[公式StackChanリポジトリ](https://github.com/m5stack/StackChan)は、公開ソースの更新が配布済みファームウェアやアプリより遅れる場合があると明記しています。従って、ここでの「最新OSS」は公開リポジトリ上の最新であり、接続実機の工場ファームウェアより新しいという意味ではありません。

ESP-IDFは[公式v5.5.4文書](https://docs.espressif.com/projects/esp-idf/en/v5.5.4/esp32s3/index.html)に合わせます。Nixpkgsの別バージョンを暗黙採用せず、公式Gitコミットとツールチェーンを`.local/`に導入します。Nixはホスト側のCMake、Python、コンパイラー補助ツールだけを固定します。

## 再現性と安全性の境界

- `flake.lock`: ホスト用CLIとライブラリを固定する。
- `versions.env`: Arduinoの配布版と主要上流コミットを固定する。
- `config/upstream.lock`: URL、ref、実体コミット、配置先を固定する。
- `.local/`: ダウンロードしたCore、ライブラリ、ESP-IDF、ビルド成果物を置く。Git管理しない。
- `.env`: 接続実機の生USBシリアルを置く。権限`0600`でGit管理しない。
- `.local/backups/`: Wi-Fi等を含み得る全Flashイメージを置く。絶対に公開しない。

ライブラリの依存自動解決は将来版を混入させるため使わず、必要な依存を個別に版指定して導入します。
