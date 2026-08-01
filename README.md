# m5stack

M5Stack StackChan（SKU K151）を主対象に、再現可能な開発環境と安全ゲート付きの実機手順をまとめた公開リポジトリです。Cardputer Advも同じローカル環境でビルド対象にできます。

> **最初に見る:** [図入りの短い手順（GitHub Pages）](https://hjosugi.github.io/m5stack/)

| やりたいこと | 読む場所 |
| --- | --- |
| PC画面をCardputer／StackChanへ送る | [PC画面リンク](https://hjosugi.github.io/m5stack/screen-link.html) |
| Cardputerを完全muteする | [Cardputer mute](https://hjosugi.github.io/m5stack/cardputer-mute.html) |
| セットアップ、バックアップ、書込み、復旧 | [安全な実機操作](https://hjosugi.github.io/m5stack/safe-development.html) |
| エラーから調べる | [困ったとき](https://hjosugi.github.io/m5stack/troubleshooting.html) |

このリポジトリは次の事故を防ぐことを優先します。

- USB IDだけで製品型番を決めつける
- 工場出荷ファームウェアを保存せずに上書きする
- 接続した別のESP32へ誤って書き込む
- サーボの可動域を確保せず、リセットや新しいプログラムを実行する
- Arduino Coreや上流ソースの更新で再現不能になる
- USBシリアル番号、認証情報、FlashバックアップをGitHubへ公開する

## 現在の対象

2026-07-31、StackChan本体のUSB-C経由で次の構成を非破壊確認しました。

```text
StackChan本体 USB-C
└── USB 2.0 Hub (214b:7250)
    └── CoreS3 / ESP32-S3 native USB JTAG/Serial (303a:1001, cdc_acm)
```

公式仕様の「USB-Cで給電・データ接続するロボット本体」と「CoreS3搭載」に一致します。生のUSBシリアルは`.env`だけに権限`0600`で保存し、画面には短いSHA-256だけを表示します。調査時点ではシリアルポートを開いておらず、実機のリセット・Flash読出し・書込みもしていません。詳細は[ハードウェア調査記録](docs/hardware-inventory.md)にあります。

## 二つの開発経路

| 経路 | 固定対象 | 用途 | 自動書込み |
| --- | --- | --- | --- |
| Arduino | M5Stack Core 3.3.8、M5Unified 0.2.19、StackChan-BSP 1.1.0 | 小さな独自スケッチ | しない |
| 公式ファームウェア | StackChan 1.4.3相当の固定コミット、ESP-IDF 5.5.4 | 量産系ソースの再現ビルド | しない |

公式StackChanリポジトリ自身が、公開ソースは配布済みファームウェアより遅れる場合があると明記しています。このため、量産系をビルドできても工場出荷版より新しいとは見なしません。まず実機の全Flashを保存し、通常はOTA可能な工場ファームウェアを維持します。

固定値と取得元は[`versions.env`](versions.env)と[`config/upstream.lock`](config/upstream.lock)、選定理由は[OSS選定](docs/oss-selection.md)に記録しています。

## PC画面リンク（試験実装）

ブラウザーで明示的に選んだPC画面またはウィンドウを、同じLAN上の端末へJPEG列として送る試験実装があります。音声は送信しません。端末ごとの実装と手順は混在させず、別ディレクトリに分けています。

| 対象 | ディレクトリ | 表示サイズ | 備考 |
| --- | --- | --- | --- |
| PC relay | [`pc/screen-link/`](pc/screen-link/) | 送信元 | GNOME/Waylandでもブラウザーの画面共有APIを使用 |
| Cardputer Adv | [`cardputer/screen-link/`](cardputer/screen-link/) | 240×135 | speaker未初期化を既定にしてmute |
| StackChan | [`stackchan/screen-link/`](stackchan/screen-link/) | 320×240 | 公式1.4.3系のAVATAR WebSocket表示を利用 |

StackChanのコミュニティ版v1.0.0には、このPC画面受信経路はありません。画面リンク版のビルドはできますが、ファームウェアを自動で置換しません。

## 最短の安全な手順

```bash
direnv allow
make setup
make detect
make init
./scripts/select-board.sh stackchan
make build
```

ここまではUSBシリアルポートを開かず、リセットも書込みも行いません。`direnv`を使わない場合は、各コマンドを`nix develop --command ...`で実行できます。

公式ファームウェアもビルドする場合は次を実行します。初回はESP-IDFツールチェーンを`.local/`へダウンロードします。

```bash
make setup-stackchan
make build-stackchan
```

## 実機を操作する前に

StackChanの頭部、台座、USBケーブルの周囲を空けてください。モーター部を手で無理に回してはいけません。その上で、必要な操作だけを明示的に実行します。

```bash
./scripts/grant-port-access.sh
./scripts/backup-flash.sh --allow-reset
```

Arduino確認スケッチで工場ファームウェアを置換する操作には、検証済みバックアップに加えて二重の許可が必要です。

```bash
./scripts/upload.sh --allow-flash --replace-factory-firmware
```

このリポジトリのセットアップには書込みは不要です。詳細は[安全な実機手順](docs/safe-workflow.md)を先に読んでください。

## コマンド

```text
make detect            USB属性だけを読む
make init              実機固有値を非公開.envへ保存する
make list              対応製品を一覧表示する
make select MODEL=...  本体型番を選択する
make setup             Arduinoの固定版をローカル導入する
make build             選択製品向けに確認スケッチをビルドする
make matrix            代表製品向けにビルドする
make setup-stackchan   固定版ESP-IDFと上流ソースを導入する
make build-stackchan   公式ファームを日本語設定でビルドする
make build-cardputer-screen-link  Cardputer画面リンクclientをビルドする
make build-stackchan-screen-link  StackChan画面リンク版をビルドする
make check             静的検査、秘密情報監査、単体テストを行う
```

リセットやFlash操作はMakeの短縮ターゲットでは実行できません。許可フラグを付けて対応スクリプトを直接呼び出します。

## ドキュメント

- [詳しい使い方（初回導入から復旧まで）](docs/usage.md)
- [接続中ハードウェアの調査記録](docs/hardware-inventory.md)
- [OSSとバージョンの選定](docs/oss-selection.md)
- [安全なセットアップ・バックアップ・書込み](docs/safe-workflow.md)
- [StackChan公式ファームウェアの再現ビルド](docs/stackchan-factory.md)
- [復旧とUSBトラブル対応](docs/recovery.md)
- [実施内容の作業記録](docs/work-log.md)
- [依存関係の更新手順](docs/updating.md)

## ライセンス

このリポジトリ独自のコードと文書は[MIT License](LICENSE)です。取得する各OSSには、それぞれのライセンスが適用されます。上流ソースやビルド成果物はGit管理しません。
