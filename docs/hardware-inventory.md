# ハードウェア調査記録

## 結論

接続対象はM5Stack StackChan（SKU K151）です。ユーザーが指定した[公式StackChanリポジトリ](https://github.com/m5stack/StackChan)を製品情報の基準にしました。USBの実測だけで型番を推測した結果ではありません。

StackChanはCoreS3を主制御器として使い、公式仕様ではESP32-S3、16 MB Flash、8 MB PSRAMを搭載します。ロボット本体側のUSB-Cは給電とデータ接続を兼ねます。

## 2026-08-01の対象分離後の観測

対象を一台だけ接続し、USB/sysfsとESP32-S3 Boot ROMから次を確認しました。Boot ROM確認は本体をリセットしますが、eFuseやFlashを書き換えません。

| 項目 | 観測値 |
| --- | --- |
| USB機器 | Espressif USB JTAG/serial debug unit、VID:PID `303a:1001` |
| Linuxドライバー | `cdc_acm` |
| デバイスノード | `/dev/ttyACM0`（安定名は`/dev/serial/by-id/`配下） |
| SoC | ESP32-S3、revision v0.2、dual core、240 MHz |
| Flash | 16 MB、Quad、3.3 V |
| セキュリティ | Secure Boot無効、Flash Encryption無効 |
| ポート権限 | 一時ACL付与後、現在ユーザーから読書き可能 |

USBシリアル番号は確認しましたが、公開文書とGit履歴には記録しません。ローカルの`.env`では対象取り違え防止に使用し、スクリプト出力ではSHA-256先頭12文字または`[redacted]`へ置き換えます。

`303a:1001`自体は多数のESP32-S3機器で共通するため、このIDだけでは製品型番を確定できません。製品型番は本体、ユーザー指定、公式仕様と合わせて固定しています。

## 2026-07-31のUSB Hub観測の訂正

当初は外付けUSB Hub配下に複数のESP32-S3機器が接続されており、そのHubをStackChan内部構成と誤って関連付けました。公式回路図と物理的な抜き差しで切り分けると、K151の主制御器は一つのCoreS3であり、Hubともう一台のESP32は別接続でした。

このため、製品内部の観測結果として`214b:7250`を扱いません。実機の固定には最終的に分離確認した一台のUSBシリアルを使っています。

## 接続の安定性

接続確認中、USB controller側でprotocol error `-71`と再列挙失敗が発生しました。対象controllerを限定して復旧した後、CoreS3は安定して列挙され、安定名も作成されました。

再発時はファームウェアより先に次を確認します。

1. USB-Cプラグを差し直す。
2. データ通信対応の短いケーブルへ交換する。
3. PC側の別ポートへ直結し、外付けHubを避ける。
<<<<<<< HEAD
4. `make detect`を繰り返し、同じ短縮SHA-256の一台が安定して見えることを確認する。
||||||| 25f29cd
4. `make detect`を繰り返し、同じ機器が安定して見えることを確認する。
=======
4. `task device:detect`を繰り返し、同じ機器が安定して見えることを確認する。
>>>>>>> agent/go-task-migration

## Flash読出しと書込み

- 16 MB全Flash読出しは115200/460800 baud、1 MiB/64 KiB/4 KiB分割で試したが、USB転送停止が再発して完了しなかった。
- 不完全データは削除し、検証済みバックアップmarkerは作っていない。
- 公式M5Burnerを公式配布元から取得し、工場版への復旧経路を先に確保した。
- `stack-chan/stack-chan` v1.0.0の配布ZIPをSHA-256検証し、K151用三領域を書き込んだ。
- bootloader、partition table、applicationの書込み後ハッシュ検証はすべて成功した。
- 再起動ログでK151専用PY32、サーボ電源、頭部タッチ、ローカル音声エンジンの初期化を確認した。

サーボの実移動、タッチ、LED、カメラ、音量、Wi-Fiはログだけでは合格とせず、[コミュニティ版手順](community-firmware.md)に沿って物理確認します。

## Cardputer Advについて

`config/boards.tsv`にはCardputer Advも登録しています。Cardputer AdvはM5Stack Board Manager上ではCardputer用FQBNを使用しますが、接続中のStackChanとは別の実機として扱います。同時に複数台を接続した場合、検出スクリプトは曖昧なまま進まず、`.env`のUSBシリアルで一台へ固定するよう要求します。
