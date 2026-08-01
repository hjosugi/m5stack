# Bruce 1.16とCardputer-Adv

## 結論

Bruce 1.16はCardputer-Advを実装上サポートしています。単一の`Bruce-m5stack-cardputer.bin`が起動時にADVのTCA8418キーボードを検出し、ADVならES8311音声codecと専用ピン設定へ切り替えます。

ただしBruceは、Wi-Fi、BLE、USB HID、赤外線、RF等のセキュリティ試験機能を含む第三者製ファームウェアです。所有または明示的な許可のある機器・電波環境だけで使用し、工場ファームウェアの復元経路を用意してから導入を判断します。本リポジトリではBruceを実機へ書き込んでいません。

## 確認した版と配布物

| 項目 | 確認値 |
| --- | --- |
| Release | [`1.16`](https://github.com/BruceDevices/firmware/releases/tag/1.16) |
| tag commit | `59e83bfbd8a63a6b67ea23498e15c710a1ed9657` |
| 公開日 | 2026-07-24 |
| Cardputer配布物 | `Bruce-m5stack-cardputer.bin` |
| size | 4,153,760 bytes |
| SHA-256 | `a0e1346db08fdfe7adf4a8f206530fc9ed1a4e2f551d91512000d0a2889bee77` |
| license | AGPL-3.0 |

GitHub Release APIのdigestだけでなく、配布binを実際にダウンロードして同じSHA-256になることを確認しました。

## Cardputer-Adv対応の根拠

BruceのREADMEはCardputerとADVを同じ行にまとめていますが、実コードは差分を処理しています。

- [Cardputerのinterface](https://github.com/BruceDevices/firmware/blob/59e83bfbd8a63a6b67ea23498e15c710a1ed9657/boards/m5stack-cardputer/interface.cpp)がTCA8418を初期化し、成功時に`UseTCA8418=true`としてADVを判定する。
- ADVではキーボード、I2C、GPS、CC1101、NRF24用のピン割当を切り替える。
- 同じファイルの`_setup_codec_speaker()`がADVのES8311を設定する。
- [ビルド設定](https://github.com/BruceDevices/firmware/blob/59e83bfbd8a63a6b67ea23498e15c710a1ed9657/boards/m5stack-cardputer/m5stack-cardputer.ini)はTCA8418、ES8311、マイク、USB HID、microSD等を有効にする。

READMEのSpeaker欄は`NS4168`とだけ表示しますが、公式Cardputer-Advの構成はES8311 + NS4150Bです。これはADV非対応を意味しません。Bruceの実コードはADV検出後にES8311を設定しており、READMEの表記が初代Cardputer寄りに簡略化されています。

## 内蔵だけで使えるものと外付けが必要なもの

READMEの`:ok:`は、その無線chipが本体へ内蔵されているという意味ではありません。

| 分類 | 機能 | 条件 |
| --- | --- | --- |
| 内蔵 | Wi-Fi、BLE | ESP32-S3の無線を使用 |
| 内蔵 | 赤外線送信 | 本体IR LEDを使用。受信は別hardwareが必要 |
| 内蔵 | マイク、スピーカー、画面、キーボード、microSD、USB HID | ADV用codec・キーボードを実装が検出 |
| 外付け | CC1101 Sub-GHz | CC1101 moduleと配線が必要 |
| 外付け | NRF24 | nRF24L01系moduleと配線が必要 |
| 外付け | PN532 RFID/NFC | PN532 moduleが必要 |
| 外付け | FM送信 | Si4713 moduleが必要 |
| 外付け | Ethernet | W5500 moduleが必要 |

外付けmoduleはmicroSDとSPI線を共有する構成があります。同時利用、電圧、chip select、Grove／拡張端子のピン割当を確認せず接続しません。

## Bruceでミュートする

`Q`ではなく、`Config`から`Audio Config`を開き、`Sound: ON`を選択して`Sound: OFF`へ切り替えます。`Sound Volume`では10〜100%を選べます。設定はBruceの設定ファイルへ保存されます。Cardputer-Advでの移動keyを含む手順は[ミュート手順](cardputer-mute.md)にまとめています。

これは公式UserDemoの`Q`静音とは別の実装です。Bruceの音声再生コードは`Sound: OFF`を確認しますが、外付け機器が独自に出す音までは制御しません。

## 導入を判断する前の安全確認

1. [Cardputer-Adv公式復元手順](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)とM5Burnerを先に用意する。
2. 対象がCardputer-Advであり、接続ポートが一台に絞れていることを確認する。
3. 公式Bruce Releaseのファイル名、size、SHA-256を上表と照合する。
4. 現在のファームウェアと設定が置換されることを理解する。
5. 外付けRF moduleを接続せず、まず内蔵hardwareだけで起動確認する。
6. セキュリティ試験機能は自分の設備または明示的な許可範囲だけで使用する。

BruceのWeb Flasher、M5Burner、M5LauncherはいずれもFlashを変更する経路です。単にREADMEを読むことと、実機へ導入することを分けて判断してください。

## 参照先

- [Bruce 1.16 Release](https://github.com/BruceDevices/firmware/releases/tag/1.16)
- [Bruce公式リポジトリ](https://github.com/BruceDevices/firmware/tree/59e83bfbd8a63a6b67ea23498e15c710a1ed9657)
- [Cardputer-Adv公式hardware仕様](https://docs.m5stack.com/en/core/Cardputer-Adv)
- [Cardputer-Adv工場ファームウェア復元](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)
- [Cardputer-Adv firmware構成](cardputer-firmware-guide.md)
