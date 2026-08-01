# M5Stackとマイコンの全体像

## 最初に覚える四つ

GitHubの`m5stack`トピックにある多数のリポジトリを全部理解する必要はありません。Cardputer-Advを使うなら、まず次の四つを区別します。

| 名前 | 役割 |
| --- | --- |
| ESP32-S3 | プログラムを実行するマイクロコントローラー（マイコン） |
| Cardputer-Adv | ESP32-S3へ画面、キーボード、音声、電池等を組み合わせた完成品 |
| Arduino | ESP32向けC++プログラムを比較的簡単にビルドする開発基盤 |
| M5Cardputer／M5Unified／M5GFX | キーボード、音声、センサー、画面を操作する公式ライブラリ |

マイコンは通常、PCのように複数アプリをOS上で同時実行するのではなく、書き込んだ一つのファームウェアがhardwareを直接制御します。Arduinoでは起動時に一度だけ`setup()`を実行し、その後`loop()`を繰り返すのが基本形です。

```cpp
void setup() {
  // 起動時に一度だけ実行
}

void loop() {
  // 電源が入っている間、繰り返し実行
}
```

## Cardputer-AdvとCardputerZeroは別物

| 項目 | Cardputer-Adv | CardputerZero |
| --- | --- | --- |
| 中心部品 | ESP32-S3 | Raspberry Pi CM0 |
| 分類 | マイコン端末 | Linux PC |
| RAM | ESP32-S3内蔵SRAM中心 | 512 MB LPDDR2 |
| 得意 | センサー、キー、赤外線、IoT、低消費電力 | Linux、SSH、一般的なLinuxソフト |
| 状態 | 製品文書と開発環境あり | 公式文書上はWork in progress |

見た目と名前が似ていても、開発手順や動くソフトは共通ではありません。Cardputer-Advへ一般的なLinuxアプリをそのままインストールすることはできません。

## Cardputer-Advに最初からあるもの

- ESP32-S3FN8、8 MB Flash
- 240×135の1.14インチ画面
- 56キーのキーボード
- Wi-Fi 2.4 GHz、Bluetooth LE
- マイク、ES8311 audio codec、1 Wスピーカー、3.5 mm出力
- BMI270加速度・ジャイロセンサー
- 赤外線送信LED
- microSD、USB-C、Grove、14ピン拡張端子
- 1750 mAhバッテリー

NFC、RFID、LoRa、Sub-GHz、Zigbee／Thread用802.15.4無線は内蔵していません。対応アプリのメニューがあっても、外付けmoduleが必要な場合があります。

## M5Stackの製品名

| 名前 | 意味 |
| --- | --- |
| Core／Controller | 画面、電池、入出力を備えた本体 |
| Stamp | ESP32を載せた小型の中核基板 |
| Atom | 非常に小さい組み込み向け本体 |
| Stick | 細長い小型画面付き本体 |
| Unit | Groveケーブル等で接続するセンサーや入出力 |
| Module／Base | Coreの上下へ組み合わせる拡張部品 |
| HAT | 主にStick系へ装着する拡張部品 |
| Cap | Cardputer等へ装着する拡張部品 |
| Grove | 電源と通信線をまとめた4ピン接続規格 |

Groveはコネクターの形です。中ではI2C、UART、GPIO等のいずれかを使うため、端子が合うだけで互換になるわけではありません。

## よく出る通信方式

| 用語 | 用途 |
| --- | --- |
| GPIO | ON／OFFの直接入出力 |
| I2C | 2本の信号線でセンサー等を接続 |
| SPI | 画面、microSD、無線module等の高速通信 |
| UART | GPSや別マイコンとのシリアル通信 |
| PWM | LEDの明るさやサーボ等の周期制御 |
| ADC | 電圧を数値として読み取る |

同じピンをmicroSDと外付けSPI moduleが共有する場合があります。配線前に対象製品のPinMapとアプリの設定を照合します。

## 開発ツールの違い

| ツール | 用途 | 使う場面 |
| --- | --- | --- |
| M5Burner | 完成済みファームウェアの書込みと工場版復元 | 既存firmwareを試す時 |
| UiFlow2 | ブロックまたはMicroPython系の開発 | 電子工作の動きを早く試す時 |
| Arduino | C++、豊富なライブラリ、サンプル | Cardputer開発の基本 |
| PlatformIO | editor統合、依存管理、複数環境 | 既存PlatformIO projectを扱う時 |
| ESP-IDF | Espressif公式の低レベルSDK | Arduinoで足りない時 |
| ESPHome | YAML中心のHome Assistant端末 | スマートホーム用途 |

このリポジトリではArduino CLI、公式M5Stack Board Manager、Nix、Go Taskを固定し、GUIへ依存しない再現可能な経路を使います。`Makefile`は使いません。

```bash
nix develop --command task arduino:setup
nix develop --command task arduino:matrix
```

## 公式ライブラリの関係

- `M5Cardputer`: Cardputer／Cardputer-Adv固有のキーボード等を扱う。
- `M5Unified`: M5Stack製品共通の画面、ボタン、電源、音声、IMU等を扱う。
- `M5GFX`: `M5Unified`が利用する画面描画基盤。
- `LovyanGFX`: M5GFXの基礎にある汎用描画ライブラリ。最初から直接操作する必要はない。

公式`m5stack/M5Stack`リポジトリは残っていますが、READMEでdeprecatedと明記され、M5GFXとM5Unifiedへの移行を案内しています。Cardputerの新規コードでは`M5Stack.h`を基準にしません。

## GitHubで見かけるリポジトリの分類

| 例 | 分類 | 最初に見るか |
| --- | --- | --- |
| `m5stack/M5Cardputer`、`M5Unified`、`M5GFX` | 公式hardware library | 見る |
| `m5stack/M5Cardputer-UserDemo` | 公式デモfirmware | 見る。ADVは専用branchも確認 |
| `m5stack/m5-docs`／公式docsサイト | 製品仕様と手順 | Web版を正本として見る |
| `terremoth/awesome-m5stack-cardputer` | 非公式リンク集 | アイデア探しに使う |
| `stack-chan/stack-chan` | ロボット本体とアプリ基盤 | StackChan用途で見る |
| `BruceDevices/firmware`、Marauder、BadUSB系 | セキュリティ試験firmware | 初学用にしない |
| GUI、RTSP、Home Assistant等の汎用project | 特定用途の部品 | 作りたい物が決まってから見る |

GitHub Topicへの登録は自己申告を含みます。星の数や更新日時だけで採用せず、対象board、Release、license、復旧方法、未解決Issueを確認します。

## おすすめの学習順

1. [Cardputer-Advの基本操作](cardputer-adv.md)で工場デモ、電源、復元方法を確認する。
2. 画面へ文字を表示する。
3. キーと`G0`の入力を表示する。
4. microSDへ小さなファイルを保存する。
5. Wi-Fiへ接続し、時刻等の公開データを表示する。
6. IMUや赤外線等を一つずつ試す。
7. 必要になってからGrove Unitや外付けmoduleを一つ追加する。

最初からESP-IDF、基板設計、複数の無線module、ローカルLLM、セキュリティ試験firmwareを同時に扱う必要はありません。このリポジトリには、画面とネットワークを組み合わせる具体例として[PC画面リンク](screen-link.md)があります。

## 主な一次資料

- [Cardputer-Adv公式仕様](https://docs.m5stack.com/en/core/Cardputer-Adv)
- [CardputerZero公式仕様](https://docs.m5stack.com/en/CardputerZero)
- [ESP32-S3公式製品情報](https://www.espressif.com/en/products/socs/esp32-s3)
- [M5Cardputer公式library](https://github.com/m5stack/M5Cardputer)
- [M5Unified](https://github.com/m5stack/M5Unified)
- [M5GFX](https://github.com/m5stack/M5GFX)
