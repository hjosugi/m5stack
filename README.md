# m5stack

M5Stack StackChan（SKU K151）を主対象に、再現可能な開発環境と安全ゲート付きの実機手順をまとめた公開リポジトリです。Cardputer Advも同じローカル環境でビルド対象にできます。

このリポジトリは次の事故を防ぐことを優先します。

- USB IDだけで製品型番を決めつける
- 工場出荷ファームウェアの復旧経路を用意せずに上書きする
- 接続した別のESP32へ誤って書き込む
- サーボの可動域を確保せず、リセットや新しいプログラムを実行する
- Arduino Coreや上流ソースの更新で再現不能になる
- USBシリアル番号、認証情報、FlashバックアップをGitHubへ公開する

## 現在の対象

2026-08-01、StackChan本体を他のESP32機器から分離し、USB-C経由で次の構成を確認しました。

```text
StackChan本体 USB-C
└── CoreS3 / ESP32-S3 native USB JTAG/Serial (303a:1001, cdc_acm)
```

Boot ROMからESP32-S3 revision v0.2、16 MB Flash、Secure Boot無効、Flash Encryption無効を確認しました。生のUSBシリアルは`.env`だけに権限`0600`で保存し、公開出力では短いSHA-256へ置き換えます。

工場Flashの全読出しはUSB転送停止のため完了しなかったので、未完成データと復旧markerは残していません。代わりに公式M5Burnerによる復旧経路を先に確保し、検証済みの[Stack-chanコミュニティ版v1.0.0](https://github.com/stack-chan/stack-chan/releases/tag/v1.0.0)を書き込みました。起動ログでK151専用サーボ、PY32、頭部タッチ、ローカル音声エンジンの初期化まで確認しています。詳細は[ハードウェア調査記録](docs/hardware-inventory.md)と[コミュニティ版の導入・使い方](docs/community-firmware.md)にあります。

## 三つの開発経路

| 経路 | 固定対象 | 用途 | 書込み |
| --- | --- | --- | --- |
| Arduino | M5Stack Core 3.3.8、M5Unified 0.2.19、StackChan-BSP 1.1.0 | 小さな独自スケッチ | しない |
| 公式ファームウェア | StackChan 1.4.3相当の固定コミット、ESP-IDF 5.5.4 | 量産系ソースの再現ビルド | しない |
| コミュニティ版 | stack-chan/stack-chan v1.0.0、配布ZIPのSHA-256固定 | K151向けホスト、MOD、Blockly、顔・動作のカスタマイズ | 明示許可時だけ |

公式StackChanリポジトリ自身が、公開ソースは配布済みファームウェアより遅れる場合があると明記しています。このため、量産系をビルドできても工場出荷版より新しいとは見なしません。工場版を維持する場合は全Flash保存を優先し、置換する場合は全Flashバックアップまたは公式M5Burnerの復旧経路を先に用意します。

固定値と取得元は[`versions.env`](versions.env)と[`config/upstream.lock`](config/upstream.lock)、選定理由は[OSS選定](docs/oss-selection.md)に記録しています。

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

K151向けコミュニティ安定版を導入する場合は、[コミュニティ版の導入・使い方](docs/community-firmware.md)に従います。固定ZIP、対象機種、書込みアドレス、セキュリティ状態を検証する専用スクリプトも用意しています。

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
make check             静的検査、秘密情報監査、単体テストを行う
```

リセットやFlash操作はMakeの短縮ターゲットでは実行できません。許可フラグを付けて対応スクリプトを直接呼び出します。

## ドキュメント

- [詳しい使い方（初回導入から復旧まで）](docs/usage.md)
- [Stack-chanコミュニティ版の導入・使い方](docs/community-firmware.md)
- [接続中ハードウェアの調査記録](docs/hardware-inventory.md)
- [OSSとバージョンの選定](docs/oss-selection.md)
- [安全なセットアップ・バックアップ・書込み](docs/safe-workflow.md)
- [StackChan公式ファームウェアの再現ビルド](docs/stackchan-factory.md)
- [復旧とUSBトラブル対応](docs/recovery.md)
- [実施内容の作業記録](docs/work-log.md)
- [依存関係の更新手順](docs/updating.md)

## ライセンス

このリポジトリ独自のコードと文書は[MIT License](LICENSE)です。取得する各OSSには、それぞれのライセンスが適用されます。上流ソースやビルド成果物はGit管理しません。
