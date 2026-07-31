# 安全な実機ワークフロー

## 0. 物理安全

StackChanは起動するファームウェアによってサーボへ給電し、頭部が動く可能性があります。

- 平らで安定した場所へ置く。
- 頭部、台座、USBケーブルの周囲を空ける。
- 顔や指を可動部へ近づけない。
- モーター接続部を手で無理に回さない。
- バッテリーとUSBの状態を把握し、作業中に抜けないようにする。

## 1. 書込みを伴わない準備

```bash
direnv allow
make setup
make detect
make init
./scripts/select-board.sh stackchan
make build
```

`detect`はsysfsだけを読み、シリアルポートを開きません。`init`は検出した生USBシリアルを`.env`へ権限`0600`で保存します。`select-board`により製品名、FQBN、SoC、Flash容量が一組で固定されます。

`build`はM5Unifiedの最小確認スケッチをCoreS3向けにコンパイルするだけです。サーボ制御コードは含みませんが、まだ実機へ書き込まないでください。

## 2. ポート権限

接続中のデバイスノードだけに、現在のユーザー向け一時ACLを設定します。

```bash
./scripts/grant-port-access.sh
```

恒久的な`udev`ルールや広いグループ権限は追加しません。USBを抜くとACLは失われます。

## 3. 工場出荷Flashの保存

物理安全を再確認し、リセットを許可して実行します。

```bash
./scripts/backup-flash.sh --allow-reset
```

スクリプトは次を強制します。

1. `.env`のUSBシリアル、VID:PID、安定ポートが現在の一台と一致する。
2. 選択製品が対応表にある。
3. セキュリティ情報を確認し、Secure BootまたはFlash Encryption有効時は中止する。
4. StackChan/CoreS3の16 MB全体を読出す。
5. 容量とSHA-256を検証する。
6. 生USBシリアルを含まないメタデータと、書込み許可用markerを作る。

バックアップは`.local/backups/`に保存されます。NVSにはWi-Fi認証情報やアプリ設定が含まれ得るため、Git、クラウド共有、チャットへ添付しないでください。

## 4. シリアル監視

シリアルポートを開くだけでもDTR/RTSによってESP32がリセットする場合があります。

```bash
./scripts/monitor.sh --allow-reset
```

## 5. Arduinoスケッチの書込み

StackChanでは、検証済みの全Flashバックアップと二つの明示許可が揃った場合だけ書込みます。

```bash
./scripts/upload.sh --allow-flash --replace-factory-firmware
```

この操作は工場ファームウェア、OTAスロット、アプリ、設定を置換し得ます。通常の環境構築やビルド検証には不要です。書込み後は、起動時の不意な動きに備えて手を離して観察します。

## 6. 公式ファームウェア

公式ソースはビルドできますが、自動Flash用ターゲットは用意していません。公開ソースが実機の配布版より遅れる可能性があるためです。[StackChan公式ファームウェアの再現ビルド](stackchan-factory.md)と[復旧手順](recovery.md)を参照してください。
