# Stack-chanコミュニティ版の導入・使い方

このページはM5StackChan AI Desktop Robot（SKU K151、CoreS3）へ、[`stack-chan/stack-chan`](https://github.com/stack-chan/stack-chan)の安定版を導入する手順です。M5Stackの工場ファームウェアとは別実装で、書き込むと工場版を置換します。

本リポジトリでは2026-08-01時点の安定版`v1.0.0`を使用します。配布ZIPのSHA-256は[`versions.env`](../versions.env)へ固定しています。移動する`develop`ブランチを実機へ直接書き込みません。

## できること

- K151専用のPY32電源制御、SCS0009サーボ、頭部タッチ、LED、CoreS3画面を使う。
- JavaScriptまたはTypeScriptのMODで顔、動作、入力、音声、カメラ、通信を拡張する。
- ブラウザーのMOD Gallery、Blockly Editor、Face Editor、Simulatorを使う。
- 本体内のStack-chan Voice、またはVOICEVOX、ElevenLabs、OpenAI等と連携する。

## 書込み前の準備

1. StackChanを平らな場所へ置き、頭部、台座、USBケーブルの周囲を空ける。
2. M5Burner、シリアルモニター、ESPHome等、ポートを使うアプリを終了する。
3. 対象一台だけをデータ対応USB-Cケーブルで接続する。公式文書どおり台座側USB-Cを推奨する。
4. 可能なら`./scripts/backup-flash.sh --allow-reset`で16 MB全体を保存する。
5. 全Flash読出しが完了しない場合は、先に[M5Stack公式StackChan文書](https://docs.m5stack.com/en/StackChan/)とM5Burnerを用意し、工場版へ戻せることを確認する。

不完全なFlash読出しを復旧用バックアップとみなしません。本リポジトリのスクリプトは途中失敗時に未完成ディレクトリを削除し、検証済みmarkerを作りません。

## 方法A: 配布元Web Installer

環境構築なしで試す場合の配布元推奨手順です。

1. Chrome、Edge、Brave等のWeb Serial対応ブラウザーで[Web Firmware Installer](https://stack-chan.github.io/stack-chan/web/flash/)を開く。
2. 本体底面のRSTを緑LEDが点灯するまで長押しし、ダウンロードモードへ入る。
3. 機種は必ず`M5StackChan CoreS3`を選ぶ。汎用の`M5Stack CoreS3`はK151専用サーボ・電源構成ではない。
4. `Flash Stack-chan firmware`、シリアルポート、`INSTALL STACK-CHAN`、`INSTALL`の順に選ぶ。
5. 書込み中はUSBや電源を抜かず、完了後にRSTを短く押す。
6. 数秒後に顔が表示されることを確認する。

## 方法B: 固定版をCLIで検証して書き込む

まずローカルの対象固定とアクセスを確認します。

```bash
direnv allow
make detect
make init
./scripts/select-board.sh stackchan
./scripts/grant-port-access.sh
```

検証済み全Flashバックアップがある場合は次を実行します。

```bash
./scripts/install-community-stackchan.sh \
  --allow-flash \
  --replace-factory-firmware
```

全Flashバックアップがなく、公式M5Burnerによる復旧を先に準備した場合だけ、追加許可を付けます。

```bash
./scripts/install-community-stackchan.sh \
  --allow-flash \
  --replace-factory-firmware \
  --official-recovery-ready
```

スクリプトは次を検証します。

- `.env`で固定した一台、製品型番、USB VID/PID、実ポートが一致する。
- GitHub ReleaseのZIPが固定SHA-256と一致する。
- `m5stackchan_cores3`用bootloaderとapplicationがESP32-S3イメージである。
- Secure BootとFlash Encryptionが無効である。
- 配布元manifestどおり`0x0`へbootloader、`0x8000`へpartition table、`0x10000`へapplicationを書き込む。
- esptoolによる書込み後ハッシュ検証が成功する。

## 初回Wi-Fi設定

Wi-Fi未設定時の起動ログに`No Wi-Fi SSID`と出るのは正常です。BLE設定モードへ入ります。

1. CoreS3の画面に触れたままRSTを短く押し、設定画面が出るまで触れ続ける。
2. Web Bluetooth対応ブラウザーで[Preferences](https://stack-chan.github.io/stack-chan/web/preference/)を開く。
3. `Connect Stack-chan with BLE`を押し、`STK`を選ぶ。
4. Wi-FiのSSIDとパスワード等を入力し、`Submit`を押す。
5. `Preference set`を確認して再起動する。

Wi-FiパスワードやAPIキーはブラウザーから本体へ直接設定します。`.env`、文書、Issue、Git commitへ書きません。

## MODを試す

1. [MOD Gallery](https://stack-chan.github.io/stack-chan/web/mod-gallery/)を開く。
2. まずSimulatorで動作を確認する。
3. `look-around`等の小さなサンプルを選び、実機インストール時は頭部の可動範囲を空ける。
4. MOD導入後は製品既定動作ではなく、そのMODがボタンや画面操作を決めることに注意する。

主なブラウザーツール:

- [Block Editor](https://stack-chan.github.io/stack-chan/web/editor/): BlocklyでMODを作る。
- [Face Editor](https://stack-chan.github.io/stack-chan/web/face-editor/): 目と口を配置する。
- [Simulator](https://stack-chan.github.io/stack-chan/web/simulator/): 実機へ入れる前に動作確認する。

## 工場版へ戻す

1. StackChanの可動範囲を空ける。
2. [M5Stack公式StackChan文書](https://docs.m5stack.com/en/StackChan/)からM5Burnerを入手する。
3. RSTを緑LEDが点灯するまで長押しし、ダウンロードモードへ入る。
4. M5Burnerで`StackChan`を検索し、`Only Official`を有効にする。
5. 公式イメージを`Download`し、対象ポートを確認して`Burn`する。
6. 再起動後に画面、サーボ、音声、Wi-Fi設定を確認する。

同じ実機から取得した検証済み16 MBバックアップがある場合は、[`restore-flash.sh`](../scripts/restore-flash.sh)でも全体を戻せます。

## 2026-08-01の実機確認

- 配布ZIPの固定SHA-256一致。
- bootloader/applicationのイメージ内SHA-256一致、ESP32-S3、16 MB、DIO、80 MHzを確認。
- 3領域すべての書込み後ハッシュ検証が成功。
- 再起動後に同じUSB実機として再列挙。
- 起動ログで`m5stackchan-cores3`、PY32、SCS0009用シリアル、サーボ電源、頭部タッチ、Stack-chan Voiceの初期化を確認。

実際の首振り、頭部タッチ、音量、Wi-Fi接続は物理操作を伴うため、ログ確認とは別に実機上で確認します。
