# Cardputerコミュニティソフトの見方

## awesome listは仕様書ではない

[`terremoth/awesome-m5stack-cardputer`](https://github.com/terremoth/awesome-m5stack-cardputer)は、ランチャー、ゲーム、通信、音楽、開発例等を探すための非公式リンク集です。本ページでは2026-03-26のコミット`706f12f265b0c23602eae302e784ca54db7c09d4`を確認しました。

便利な索引ですが、README冒頭の仕様は初代Cardputerのものです。Cardputer-Advではバッテリー、audio codec、speaker amplifier、IMU、キーボードcontroller、拡張端子等が異なります。リポジトリに`cardputer-adv`トピックが付いていても、掲載された各アプリがADV対応とは限りません。

## 掲載内容の分類

| 分類 | 例 | 読み方 |
| --- | --- | --- |
| ランチャー／実行環境 | M5Launcher、MicroHydra、HydraOS、BerylliumOS | 複数アプリの切替方式、対応firmware形式、ADV対応を確認 |
| ゲーム／emulator | DOOM、Game Boy、C64、Tamagotchi等 | キー配列、音声、microSD、Flash容量を確認 |
| 通信／utility | SSH、Telnet、WebRadio、天気、IR remote | 認証情報の保存場所と通信の暗号化を確認 |
| 言語／開発例 | Forth、Rust HAL、PyDOS等 | 対象boardと必要toolchainを確認 |
| セキュリティ試験 | Bruce、Marauder、BadUSB等 | 許可範囲、外付けhardware、復元経路を先に確認 |

「250+ binaries」は選択肢の数であり、Cardputer-Advでの動作保証数ではありません。

## Cardputer-Adv対応を見分ける

次をすべて満たすか確認します。

1. README、Release、build targetのいずれかに`Cardputer-Adv`またはTCA8418対応が明記されている。
2. ADVのES8311 audio codecとNS4150B amplifierを考慮している。
3. 公式ADV UserDemoと同じキーボードcontroller、または実機判定処理がある。
4. 初代Cardputer用binとADV用binが別なら、正しい方を選べる。
5. Release assetにversion、作成元、checksumがある。
6. 工場ファームウェアへ戻す方法を先に確保できる。

Bruce 1.16は単一binがTCA8418を検出してADVへ切り替えることを確認済みです。詳細は[Bruce 1.16とCardputer-Adv](bruce-cardputer-adv.md)に分離しています。他の掲載アプリは本ページ作成時点で個別の実機検証をしていません。

その後、M5Launcher、Picoware、NEMO、Poseidon、MicroHydra、CircuitPython、Game Station、MeshCore、Meshtasticを個別に再確認しました。現行版と採用結果は[Cardputer-Adv firmware構成](cardputer-firmware-guide.md)を正本とします。

## 初回動作確認の順序

1. 公式Cardputer-Adv UserDemo
2. M5Cardputer、M5Unified、M5GFXの公式example
3. source、license、対象boardが明確な小さなアプリ
4. factory復元を準備した後の[M5Launcher採用構成](cardputer-firmware-guide.md)
5. 用途と許可範囲を理解した後のセキュリティ試験firmware

最初は画面、キーボード、microSD、Wi-Fiを一つずつ確認します。複数のlauncherやfirmwareを連続で書き換えると、不具合がhardware、firmware、設定のどれにあるか分からなくなります。

## 導入前チェック

| 確認 | 理由 |
| --- | --- |
| repoのownerと公式性 | 同名・fork・非公式配布を区別する |
| 最終Releaseとcommit | 動くsourceとbinを結び付ける |
| license | 再配布や改変の条件を把握する |
| 対応機種 | 初代、v1.1、ADVを区別する |
| 必要な外付け部品 | メニュー表示とhardware内蔵を混同しない |
| checksum | 取得したbinをReleaseと照合する |
| factory復元 | 書込み失敗や非対応binから戻れるようにする |
| 秘密情報 | Wi-Fi、token、鍵を公開repoやスクリーンショットへ出さない |

リンク集のREADMEはGPL-3.0です。本ページは一覧本文を転載せず、確認方法と選定結果を独自にまとめています。

## 参照先

- [Awesome M5Stack Cardputer](https://github.com/terremoth/awesome-m5stack-cardputer/tree/706f12f265b0c23602eae302e784ca54db7c09d4)
- [Cardputer-Adv公式仕様](https://docs.m5stack.com/en/core/Cardputer-Adv)
- [M5Cardputer公式library](https://github.com/m5stack/M5Cardputer)
- [Cardputer-Adv工場ファームウェア復元](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)
