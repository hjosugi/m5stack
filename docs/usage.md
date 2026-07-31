# 詳しい使い方

このページは、初回導入から日常のビルド、実機バックアップ、書込み、復旧までを順番に説明します。StackChanでは、環境構築とビルドだけなら本体をリセットする必要はありません。

## 1. リポジトリを準備する

Nixとdirenvを使用する場合は次の通りです。

```bash
git clone git@github.com:hjosugi/m5stack.git
cd m5stack
direnv allow
```

shellへ入ると次の案内が表示されます。

```text
M5Stack開発環境: make detect / make setup / make build
```

direnvを使わない場合は、shellを明示的に開きます。

```bash
nix develop
```

一つのコマンドだけ実行することもできます。

```bash
nix develop --command make check
```

`flake.lock`によりArduino CLI、esptool、CMake、ShellCheck等のホストツールが固定されます。Arduino Core、ライブラリ、ESP-IDFはリポジトリ内の`.local/`へ導入され、ホストのグローバル環境を変更しません。

## 2. USB接続を確認する

StackChanをUSB-CデータケーブルでPCへ接続し、まだシリアルポートは開かずに確認します。

```bash
make detect
```

正常時は、概ね次の情報が表示されます。

```text
M5/ESP32 USBデバイスを1台検出しました。
  USB製品名: USB JTAG/serial debug unit
  USB ID: 303a:1001
  識別子: sha256:xxxxxxxxxxxx（生のシリアルは非表示）
  ポート: /dev/ttyACM0（by-id固定済み・実名非表示）
安全確認: シリアルポートは開いておらず、リセット・読出し・書込みは行っていません。
```

`xxxxxxxxxxxx`は実機ごとに異なる短いハッシュです。Issueやチャットへ結果を載せる場合でも、`/dev/serial/by-id/`の完全な名前は伏せてください。

複数の対応機器を同時接続すると検出は中止します。最初の設定時は対象一台だけを接続してください。

## 3. 実機をローカル設定へ固定する

```bash
make init
./scripts/select-board.sh stackchan
```

`make init`は次の値を`.env`へ保存します。

- 安定したシリアルポート名
- 生USBシリアル（対象取り違え防止用）
- USB VID/PID
- 後から選ぶ製品名とFQBN

`.env`は権限`0600`で、Git ignoreされています。内容には生USBシリアルがあるため、画面共有、Issue、チャットへ貼り付けないでください。追跡対象外であることは次で確認できます。

```bash
stat -c '%a %n' .env
git check-ignore -v .env
```

期待値は権限`600`と`.gitignore`による除外です。

製品一覧を確認するには次を使います。

```bash
make list
```

別の実機へ接続し直す場合は、対象一台だけを接続してローカル設定を明示更新します。

```bash
./scripts/init-env.sh --force
./scripts/select-board.sh cardputer-adv
```

`--force`は`.env`だけを置換します。Flashは操作しません。

## 4. Arduino環境を導入する

```bash
make setup
```

このコマンドは次を`.local/arduino/`へ固定版で導入します。

- M5Stack Arduino Core
- M5GFX / M5Unified
- M5Cardputer
- IRremoteESP8266 / M5Unit-NFC
- StackChan-BSPの固定Gitコミット

実機が未接続でも実行でき、ポートを開かず、リセットもFlash書込みも行いません。再実行は可能ですが、固定checkoutに手作業の変更がある場合は上書きせず中止します。

## 5. Arduinoスケッチをビルドする

選択した製品向けの最小確認スケッチをコンパイルします。

```bash
make build
```

StackChanの場合はCoreS3用FQBNを使用します。生成物は次に置かれます。

```text
.local/build/arduino/m5stack_esp32_m5stack_cores3/
```

この段階では実機へ書き込みません。確認スケッチはM5Unified、画面、シリアル出力を初期化しますが、StackChanのサーボ制御は含みません。

代表的なM5Stack製品すべてでコンパイル互換性を確認する場合は次を実行します。

```bash
make matrix
```

## 6. StackChan公式ファームウェアをビルドする

Arduinoスケッチとは別に、公式量産系ソースを再現ビルドできます。

```bash
make setup-stackchan
make build-stackchan
```

初回セットアップはStackChan、StackChan-BSP、ESP-IDF、submodule、ESP32-S3 toolchainを`.local/`へ取得します。ビルド時には上流依存のcommit、公式パッチ、host tests、日本語設定を検証します。

成功時の主な成果物は次です。

```text
.local/build/stackchan-factory-ja/stack-chan.bin
.local/build/stackchan-factory-ja/sdkconfig
```

これらのコマンドも実機へ書き込みません。公開ソースは接続実機の工場配布版より遅い場合があるため、生成したbinを自動適用しません。

## 7. 実機ポートへ一時的にアクセスする

ここから先は実機へ影響し得ます。StackChanを平らな場所へ置き、頭部、台座、USBケーブルの可動余裕を確認してください。

```bash
./scripts/grant-port-access.sh
```

現在のデバイスノードだけへユーザーACLを追加します。管理者認証画面が出る場合があります。恒久的なグループ変更や`udev`ルール追加は行わず、USBを抜くとACLは失われます。

## 8. 工場出荷Flashをバックアップする

この操作はESP32-S3をリセットします。サーボが動く可能性に備え、手を離してから実行します。

```bash
./scripts/backup-flash.sh --allow-reset
```

実行中は次の二段階があります。

1. セキュリティ情報を読み、Secure BootまたはFlash Encryptionが有効なら中止する。
2. StackChanの16 MB全体を読み、サイズとSHA-256を検証する。

成功時は次の構成で保存されます。

```text
.local/backups/stackchan/<UTC時刻>/
├── flash-16777216.bin
├── flash-16777216.bin.sha256
├── metadata.txt
└── security-info.txt
```

さらに`.local/backups/verified/`へ、書込みゲート用markerが作られます。FlashにはWi-Fi情報、アプリ設定、認証情報等が含まれ得ます。`.local/`の外へコピーしたりGitHubへ公開したりしないでください。

## 9. シリアルログを見る

シリアルポートを開くとDTR/RTSによって本体がリセットする可能性があります。物理安全を確認し、許可を明示します。

```bash
./scripts/monitor.sh --allow-reset
```

終了は`Ctrl-C`です。ポートが見つからない場合は、USBを差し直して`make detect`を先に実行します。

## 10. Arduino確認スケッチを書き込む

通常のセットアップには不要です。工場ファームウェアを置換する意図があり、復旧用バックアップを検証済みの場合だけ実行します。

StackChanでは二重許可が必要です。

```bash
./scripts/upload.sh --allow-flash --replace-factory-firmware
```

Cardputer Adv等、工場版置換の追加確認を課していない製品では次です。

```bash
./scripts/upload.sh --allow-flash
```

どちらも、現在接続中のUSBシリアル、VID/PID、ポートが`.env`と一致し、対象製品と同容量の全Flashバックアップmarkerがない限り中止します。

StackChanへの書込み後は工場版のAI Agent、アプリ、OTA等が使えなくなる可能性があります。起動直後は手を離し、不意な動作がないか確認してください。

## 11. 全Flashを復旧する

書込み前に保存した同じ実機のバックアップを指定します。

```bash
./scripts/grant-port-access.sh
./scripts/restore-flash.sh --allow-flash \
  .local/backups/stackchan/<UTC時刻>/flash-16777216.bin
```

スクリプトは保存場所、SHA-256、容量、現在の接続実機を検証してから、Flash全体を書き戻します。途中でUSBや電源を抜かないでください。再起動時のサーボ動作に備え、手を離して待ちます。

## 12. 日常の開発サイクル

工場ファームを維持している間の日常作業は、基本的に次だけです。

```bash
make detect
make build
make check
```

Arduinoスケッチを実機テストする段階になったら、毎回次を確認します。

1. `.env`の選択製品と、机上の実機が一致している。
2. `make detect`が一台だけを検出する。
3. 検証済みバックアップがある。
4. StackChanの可動範囲が空いている。
5. 実行するスケッチがサーボへ何を指示するか理解している。

## エラー別の確認

| 表示・症状 | 確認すること |
| --- | --- |
| 対応デバイスが見つからない | データ対応ケーブル、PC直結、別USBポート、`error -71`の有無 |
| 対応デバイスが複数台ある | 一台だけ接続するか、正しい`.env`でUSBシリアルを固定する |
| `.env`は既にあります | 同じ実機ならそのまま使う。別実機なら`init-env.sh --force` |
| ポートを読み書きできない | `grant-port-access.sh`を実行し、USB再接続後なら再度ACLを付ける |
| checkoutにローカル変更がある | `.local/`内の変更を別場所へ退避し、固定ソースを汚さず再実行する |
| Secure Boot/Flash Encryptionで中止 | eFuseを変更しない。公式復旧経路を確認する |
| 検証済みバックアップがない | 書込みを中止し、先に全Flashバックアップを作る |
| StackChanで追加フラグを要求される | 工場版を本当に置換する場合だけ`--replace-factory-firmware`を付ける |

Download Mode、USB不調、全Flash復旧の詳細は[復旧とUSBトラブル対応](recovery.md)を参照してください。

## 公開してよいもの・いけないもの

公開してよいもの:

- このリポジトリのコードと文書
- `versions.env`とcommit固定値
- 生シリアルを含まない一般的なエラーメッセージ

公開してはいけないもの:

- `.env`
- `/dev/serial/by-id/`の完全な実機固有名
- `.local/backups/`のFlashイメージとメタデータ
- Wi-Fi、APIキー、アカウント情報
- 注文、氏名、住所等の個人情報

公開前は必ず次を実行します。

```bash
make check
git status --short
```
