# Cardputer-Advの基本的な使い方

## どんな機器か

Cardputer-Advは一般的なPCではなく、ESP32-S3、240×135画面、56キー、microSD、マイク、スピーカー、赤外線、IMU、無線通信を一体化したプログラマブル端末です。工場出荷時のUserDemoは、これらの機能を確認するアプリランチャーです。

本ページは2026-08-01時点の公式製品文書と、公式UserDemoの`CardputerADV`ブランチ`b549eac0a3c65bc108186c276b8fac0a214aaa4e`を基準にしています。

## 電源、充電、G0

上側の縁にある黒い`OFF/ON`スライドスイッチが主電源です。白い`G0`ボタンは電源スイッチではありません。

| 操作 | 方法 |
| --- | --- |
| 電源ON | 黒いスイッチを`ON`へ動かす |
| 電源OFF | 黒いスイッチを`OFF`へ動かす |
| 充電 | スイッチを`ON`にしてUSB-Cへ接続する |
| アプリから戻る | `G0`を押す |
| Download Mode | スイッチを`OFF`にし、`G0`を押したままUSB-Cで給電してから離す |

公式文書は、充電時に必ず電源スイッチを`ON`へするよう指定しています。バッテリー容量は1750 mAhです。

## 公式UserDemo

ランチャーでは矢印キーでアプリを選び、`Enter`で開き、`G0`で戻ります。主なアプリは次のとおりです。

| アプリ | 用途 |
| --- | --- |
| Keyboard | BLEまたはUSBの外付けキーボードとして動作 |
| Record | マイク録音とスピーカー再生 |
| Scan | Wi-Fiアクセスポイントの検索 |
| SetWiFi | Wi-Fi設定 |
| Clock | 時計 |
| IMU | BMI270の加速度・ジャイロ確認 |
| SDCard | microSD確認 |
| Remote | 赤外線送信 |
| REPL | PikaScript環境 |
| StringIR | 文字列の赤外線送受信 |
| LoRaChat／GPS | 対応する外付けCapと組み合わせて使用 |

メイン画面の`Q`は静音モードです。詳しい対象と制約は[Cardputer-Advをミュートする](cardputer-mute.md)を参照してください。

## キーボード早見表

| 入力 | 操作 |
| --- | --- |
| 大文字・上段記号 | `Aa`を押しながら文字または数字・記号キー |
| 上 | `Fn` + `;` |
| 左 | `Fn` + `,` |
| 下 | `Fn` + `.` |
| 右 | `Fn` + `/` |
| Esc | `Fn` + `` ` `` |
| Backspace | `Del` |
| Forward Delete | `Fn` + `Del` |
| Windows／Command相当 | `Opt` |

自作Arduinoプログラムでは、キー変化を取りこぼさないようループ内で`M5Cardputer.update()`を頻繁に呼び、長いブロッキング処理を避けます。

## PCやスマートフォンのキーボードとして使う

1. UserDemoの`Keyboard`を開く。
2. `BLE Keyboard`または`USB Keyboard`を選ぶ。
3. 矢印キーで選択し、`Enter`で開始する。

BLEでは接続先のBluetooth設定から`CP-ADV Kbd XXXX`形式の名前を選びます。末尾は機器固有の2バイトです。USBではデータ通信対応のUSB-Cケーブルで接続します。

`G0`でKeyboardアプリを終了すると、HID状態を確実に解放するためUserDemoは再起動します。USB-Cケーブルが充電専用の場合はキーボードとして認識されません。

## 工場ファームウェアへ戻す

1. [Cardputer-Adv公式復元手順](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)とM5Burnerを準備する。
2. 電源スイッチを`OFF`へする。
3. `G0`を押したままデータ対応USB-Cケーブルで接続し、給電後に離す。
4. M5Burnerで`Cardputer-Adv`用の工場ファームウェアと対象ポートを選ぶ。
5. `Start`で書き込み、成功表示を確認する。

初代Cardputer用とCardputer-Adv用を混同しません。Flash書込みは現在のファームウェアと設定を置換します。本リポジトリの調査・ビルドでは実機へ書き込んでいません。

## 公式資料

- [Cardputer-Adv製品文書](https://docs.m5stack.com/en/core/Cardputer-Adv)
- [公式UserDemoのADVブランチ](https://github.com/m5stack/M5Cardputer-UserDemo/tree/CardputerADV)
- [CardputerキーボードAPI](https://docs.m5stack.com/en/arduino/m5cardputer/keyboard)
- [Arduinoのコンパイルと書込み](https://docs.m5stack.com/en/arduino/m5cardputer/program)
- [工場ファームウェア復元](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)
