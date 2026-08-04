# Cardputer ファームコレクションと使い方

M5Cardputer / Cardputer-Adv を **M5Launcher 基盤**で運用し、Bruce などのコミュニティ
ファームを SD から切り替えて使うための手順と、各ファーム／ツールの使い方をまとめる。

!!! warning "倫理・法的な前提（セキュリティ系ツール全般）"
    Bruce / NEMO などの Wi-Fi・BLE・IR・BadUSB 等の機能は、**自分が所有する機器・
    ネットワーク、または明示的に許可された検証環境でのみ**使用すること。第三者の
    ネットワークや機器への無断アクセス・妨害は多くの国・地域で違法。これらは学習と
    自機の防御・診断のための道具として扱う。

## 全体像

- **本体フラッシュ**: M5Launcher（起動基盤）を 0x0 に書き込む。
- **SD カード**: Bruce / GameStation / NEMO / MeshCore などの `.bin` を置き、Launcher
  の SD メニューから選んで本体へ書き込む（切り替え運用）。
- **復旧**: 事前に全 Flash バックアップを取得済み（`task device:backup:usbjtag:run`）。
  最悪時は M5Burner の公式ファームでも復旧できる。

## 作業タスク（Taskfile）

| 目的 | コマンド |
| --- | --- |
| 対象を Cardputer に切替 | `task target:cardputer` |
| ポート権限（一時） | `task grant` |
| ポート権限（永続 udev） | `task device:grant:persist:run` |
| 全 Flash バックアップ（USB-JTAG向け） | `task device:backup:usbjtag:run` |
| FW カタログ一覧 | `task cardputer:fw:list` |
| FW bin 取得（sha 検証） | `task cardputer:fw:fetch` |
| 本体へ 0x0 書込み | `task cardputer:fw:flash:run FW=launcher` |
| SD を FAT32 初期化＋bin配置 | `task cardputer:sd:provision:run` |

固定版カタログは `config/cardputer-firmware.tsv`（版・URL・sha256 を固定）。

## 導入の流れ（推奨）

1. `task target:cardputer` → `task grant`（初回のみ）
2. `task device:backup:usbjtag:run`（復旧用の全 Flash バックアップ）
3. `task cardputer:fw:fetch`（全 bin をダウンロード・sha 検証）
4. `task cardputer:fw:flash:run FW=launcher`（M5Launcher を本体へ）
5. Launcher の設定で SD を USB 共有 → PC 側で `task cardputer:sd:provision:run`
   （SD を FAT32 初期化し、取得済み bin を一括配置）
6. SD を本体へ戻し、Launcher の SD メニューから使いたいファームを選んで書込み

## キーボードの基本（Cardputer）

- 方向: `;`=上 `.`=下 `,`=左 `/`=右
- 決定: `Enter`、戻る/中断: `` ` ``（バッククォート）や `Esc` 相当
- 文字入力: 通常キー、記号は `Fn` / `Shift` 併用

（ファームごとに割り当ては異なる。各ファームの画面表示に従う）

## 各ファーム／ツール

### M5Launcher 2.8.0 — 起動基盤（最初に入れる）
- **役割**: 複数ファームの管理・切替。SD 上の `.bin` インストール、OTA、パーティション
  管理、FAT/SPIFFS バックアップ、Wi-Fi 設定の暗号化保存。
- **使い方**: 起動後メニューを方向キーで選択。SD メニューから `.bin` を選ぶと本体へ
  書き込み。設定から SD の USB 共有（MSC）を有効にすると PC から SD を読み書きできる。
- **ポイント**: これ自体はアプリが少ない「土台」。ここから他ファームを出し入れする。

### Bruce 1.16 — 万能ツール／セキュリティ学習（総合1位）
- **役割**: Wi-Fi スキャン・解析、BLE スキャン、IR 送受信、USB/BLE キーボード（BadUSB）、
  microSD/LittleFS ファイル管理、WebUI、JavaScript 実行、SSH/Telnet/TCP、QR、ESP-NOW、
  時計、外付け CC1101 / nRF24 / PN532 / GPS 対応。
- **Cardputer/Adv 共通**: 同じ Bruce バイナリで動作し、起動時に Adv の TCA8418 キーボードと
  ES8311 音声回路を自動判別する。
- **音を消す**: `Config → Audio Config → Sound: OFF`。
- **注意**: 開発速度が速く機能によって不具合が残ることがある。安定版 1.16 を推奨。
- **倫理**: 上記の前提を厳守（自機・許可環境のみ）。

### Cardputer Game Station 1.2 — レトロゲーム（ゲーム1位）
- **役割**: GB / GBC / NES / SNES / メガドライブ / PC Engine / Master System / Game Gear /
  Atari 2600・7800 / MSX / Neo Geo Pocket / WonderSwan など多数のエミュレータ。
- **使い方**: ROM は SD カードに置く（合法に入手した自己所有 ROM を使うこと）。Adv の
  キーボードフリーズ対策も実装済み。
- **注意**: ROM の配布・入手は各自の権利範囲で。

### NEMO 3.2.2 — セキュリティ入門（初心者向け）
- **役割**: Bruce より機能を絞った学習向けツール。BadUSB Hunter などを収録。
- **使い方**: メニューから機能を選択。Bruce より操作が簡単。
- **倫理**: 同上（自機・許可環境のみ）。

### MeshCore（Cardputer-Adv + Cap LoRa-1262）1.15.0 — LoRa メッシュ通信
- **役割**: LoRa による長距離メッセージング（MeshCore ネットワーク）。
- **前提ハード**: **Cap LoRa-1262（SX1262）が必要**。無いと通信機能は使えない。
- **注意**: 地域ごとの周波数帯（EU868 等）と法規に従うこと。ビルドは EU868 版。

## M5Burner CDN 由来（SD 導入専用 = offset `sd`）

GitHub に Cardputer 用 bin が無いものは **M5Burner の公開カタログ API**
（`https://m5burner-api.m5stack.com/api/firmware`）から実 bin を取得している。
これらは **アプリ／全体イメージで、esptool の 0x0 書込みではなく M5Launcher の
SD Install で導入**する（カタログの offset 列が `sd`）。`cardputer:fw:flash:run` は
これらを安全に拒否する。SD へは `task cardputer:sd:provision:run` で配置される。

- **Picoware 2.0.0**（jblanked）— 携帯 PC・PDA 寄り。本体上コードエディタ、Python REPL、
  ファイルマネージャ、App Store、MP3/WAV、JPEG/BMP、Wi-Fi/BLE、Game Boy エミュ、
  2048/Tetris など。SD メニューから `picoware-2.0.0.bin` を選んで Install。
- **UIFlow2 Cardputer-Adv v2.5.0**（M5Stack 公式）— Blockly + MicroPython。ブラウザで
  ブロックを組み、Wi-Fi/USB で本体へ転送して電子工作・学習。
- **Factory UserDemo Cardputer-Adv v0.3**（M5Stack 公式）— ハード動作確認・純正復旧用。
  キーボード、IR、音、マイク、Wi-Fi、Pika REPL。故障切り分けに便利。

いずれも本体の **M5Launcher → SD メニュー → 対象 `.bin` → Install** で導入する。
Wi-Fi があれば Launcher の **OTA（オンライン一覧）**からも同じものを直接導入できる。
GUI で扱いたい場合は M5Burner 本体も使える: `task m5burner:setup` → `task m5burner:run`。

## AI を使いたい場合（DeepSeek 等）

Cardputer 用の既製「AI チャット」ファームは現状見当たらない。選択肢:

- **Bruce の JavaScript 実行**や **UIFlow2（MicroPython）**から、HTTP で LLM API
  （DeepSeek など）を呼ぶスクリプトを書く。
- 専用の **DeepSeek チャットファーム（自作ビルド）** を用意する（Wi-Fi＋キーボード＋
  DeepSeek Chat Completions API＋画面）。本リポジトリには既に DeepSeek 連携の仕組みが
  あるため、Cardputer 版クライアントとして流用可能。

## 復旧

- 事前バックアップから戻す: `.local/backups/…/flash-8388608.bin` を書き戻す
  （`task device:restore` の案内に従う）。
- もしくは M5Burner の公式ファーム（UserDemo 等）で工場状態に戻す。

## 参考（入手元）

- M5Launcher: `github.com/bmorcelli/Launcher`
- Bruce: `github.com/pr3y/Bruce`（バイナリは `github.com/BruceDevices/firmware`）
- Game Station: `github.com/geo-tp/Cardputer-Game-Station-Emulators`
- NEMO: `github.com/n0xa/m5stick-nemo`
- MeshCore(ADV): `github.com/hdcasey/meshcore-cardputer-adv`
