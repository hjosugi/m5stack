# ハードウェア調査記録

## 結論

接続対象はM5Stack StackChan（SKU K151）です。ユーザーが指定した[公式StackChanリポジトリ](https://github.com/m5stack/StackChan)を製品情報の基準にしました。USBの実測だけで型番を推測した結果ではありません。

StackChanはCoreS3を主制御器として使い、公式仕様ではESP32-S3、16 MB Flash、8 MB PSRAMを搭載します。ロボット本体側のUSB-Cは給電とデータ接続を兼ねます。

## 2026-07-31の非破壊観測

LinuxのUSB/sysfsとデバイスノードだけを読み、次を確認しました。

| 項目 | 観測値 |
| --- | --- |
| 上流USB機器 | USB 2.0 Hub、VID:PID `214b:7250` |
| 子USB機器 | Espressif USB JTAG/serial debug unit、VID:PID `303a:1001` |
| Linuxドライバー | `cdc_acm` |
| デバイスノード | `/dev/ttyACM0`（安定名は`/dev/serial/by-id/`配下） |
| USB速度 | 12 Mbit/s |
| ポート権限 | `root:uucp`、モード`0660`。調査ユーザーは`uucp`未所属 |

USBシリアル番号は確認しましたが、この文書、Git履歴、コマンド出力には記録していません。ローカルの`.env`では対象取り違え防止に使用し、表示時はSHA-256先頭12文字だけにします。

この「Hubの下にESP32-S3ネイティブUSB」という構成は、USB-Cデータ端子を持つStackChan本体とCoreS3という公式構成に整合します。ただし`303a:1001`自体は多数のESP32-S3機器で共通するため、このIDだけでは製品型番を確定できません。

## 接続の安定性

接続直後、カーネルログにHubの再接続、USB protocol error `-71`、`Cannot enable. Maybe the USB cable is bad?`が繰り返し記録されました。その後はHubと子のESP32-S3が列挙され、安定名も作成されました。

再発時はファームウェアより先に次を確認します。

1. USB-Cプラグを差し直す。
2. データ通信対応の短いケーブルへ交換する。
3. PC側の別ポートへ直結し、外付けHubを避ける。
4. `task device:detect`を繰り返し、同じ機器が安定して見えることを確認する。

## この時点で行っていない操作

- シリアルポートのopen
- DTR/RTSの切替
- ブートローダーへの遷移
- eFuse/Flash情報の読出し
- Flashのバックアップ、消去、書込み
- サーボ、LED、NFC、カメラ等の動作テスト

これらは本体のリセットやサーボ動作を誘発し得るため、[安全な実機手順](safe-workflow.md)の物理安全確認後に分けて行います。

## Cardputer Advについて

`config/boards.tsv`にはCardputer Advも登録しています。Cardputer AdvはM5Stack Board Manager上ではCardputer用FQBNを使用しますが、接続中のStackChanとは別の実機として扱います。同時に複数台を接続した場合、検出スクリプトは曖昧なまま進まず、`.env`のUSBシリアルで一台へ固定するよう要求します。
