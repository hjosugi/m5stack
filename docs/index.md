# my-m5docs

このサイトは、M5Stack実機、開発環境、OSS、復旧方法について、このリポジトリで調査・検証したMarkdownを読むための索引です。製品紹介やデモではなく、手順、根拠、制約、未完了事項を確認することに絞っています。

画面上部の検索欄では、見出しだけでなく本文も日本語で検索できます。新しいMarkdownを`docs/`へ追加すると、自動的にナビゲーションと検索対象へ加わります。

## まず読む

| 文書 | 確認できること |
| --- | --- |
| [M5Stackとマイコンの全体像](m5stack-beginner.md) | ESP32、Cardputer、開発ツール、library、学習順 |
| [詳しい使い方](usage.md) | 初回導入、日常のビルド、バックアップ、書込み、復旧 |
| [安全な実機手順](safe-workflow.md) | リセットやFlashの前に必要な確認と安全ゲート |
| [ハードウェア調査記録](hardware-inventory.md) | 接続機器の特定根拠、USB観測、実機確認の限界 |
| [作業記録](work-log.md) | 調査、実装、実機操作、検証を日付順に確認 |

## PC画面リンク

| 文書 | 確認できること |
| --- | --- |
| [PC画面をCardputer／StackChanへ送る](screen-link.md) | relay、認証、端末別設定、接続確認、制約 |

## Cardputer

| 文書 | 確認できること |
| --- | --- |
| [Cardputer-Advの基本的な使い方](cardputer-adv.md) | 電源、充電、公式UserDemo、キーボード、工場版復元 |
| [Cardputer-Advをミュートする](cardputer-mute.md) | 公式UserDemoの`Q`静音、対象範囲、別ファームウェアとの差 |
| [Cardputer-Adv firmware選定](cardputer-firmware-guide.md) | M5Launcher、Bruce、Picoware、Python、game、LoRaの比較 |
| [Bruce 1.16とCardputer-Adv](bruce-cardputer-adv.md) | ADV対応の実装根拠、内蔵／外付け機能、音設定、安全上の境界 |
| [Cardputerコミュニティソフトの見方](cardputer-community-software.md) | awesome listの使い方、ADV対応の判定、導入前確認 |

## StackChan

| 文書 | 確認できること |
| --- | --- |
| [コミュニティ版の導入・使い方](community-firmware.md) | K151向け安定版、初回設定、MOD、工場版への復旧 |
| [公式ファームウェアの再現ビルド](stackchan-factory.md) | 固定した公式ソースとESP-IDFによるビルド |
| [復旧とUSBトラブル対応](recovery.md) | Download Mode、USB不調、Flash復旧 |

## 依存関係と選定根拠

| 文書 | 確認できること |
| --- | --- |
| [OSSとバージョンの選定](oss-selection.md) | 採用候補、バージョン、ライセンス、採否理由 |
| [ESP32 GitHubプロジェクトの見方](esp32-projects-guide.md) | ESP32関連projectの分類、用途、導入前確認、安全上の境界 |
| [依存関係の更新手順](updating.md) | 公式情報の再確認、固定値更新、検証項目 |

## 記録の読み方

- 「確認済み」は、文書内に書かれた日付と条件で確認した結果です。現在の最新版を意味しません。
- USB IDだけで製品型番を決めません。実機の表示、接続経路、公式仕様を合わせて判断します。
- ビルド成功と実機動作、CI成功とPages公開は、それぞれ別の確認項目です。
- 生USBシリアル、Wi-Fi、APIキー、Flashバックアップ等の非公開情報は掲載しません。
