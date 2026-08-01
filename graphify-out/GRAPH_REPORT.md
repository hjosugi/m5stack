# Graph Report - m5stack  (2026-08-01)

## Corpus Check
- 58 files · ~11,934 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 348 nodes · 576 edges · 32 communities (25 shown, 7 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 38 edges (avg confidence: 0.51)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `15ffc75b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- common.sh
- server.py
- index.md
- 詳しい使い方
- Stack-chanコミュニティ版の導入・使い方
- app.js
- M5Stackとマイコンの全体像
- m5stack
- 2026-08-01
- Cardputer Adv PC画面リンク
- PC Screen Link relay
- StackChan PC画面リンク
- test-common.sh
- cardputer/screen-link/build.sh
- PC画面をCardputer／StackChanへ送る
- 安全な実機ワークフロー
- screen_link_auth.cpp
- test-safety-gates.sh
- run.sh
- stackchan/screen-link/build.sh
- m5-screen-link
- Cardputer-Advをミュートする
- ハードウェア調査記録
- my-m5docs
- 復旧とUSBトラブル対応
- Bruce 1.16とCardputer-Adv
- test-taskfile.sh
- Cardputer-Advの基本的な使い方
- Cardputerコミュニティソフトの見方
- StackChan公式ファームウェアの再現ビルド
- main

## God Nodes (most connected - your core abstractions)
1. `die()` - 26 edges
2. `log()` - 21 edges
3. `require_command()` - 18 edges
4. `詳しい使い方` - 16 edges
5. `load_local_env()` - 13 edges
6. `Target` - 12 edges
7. `create_app()` - 12 edges
8. `FrameHub` - 11 edges
9. `upload.sh script` - 11 edges
10. `M5Stackとマイコンの全体像` - 11 edges

## Surprising Connections (you probably didn't know these)
- `test-common.sh script` --calls--> `load_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `write_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `detect_m5_usb()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `FrameHub` --uses--> `Target`  [INFERRED]
  pc/screen-link/src/m5_screen_link/server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `ProtocolTest` --uses--> `Target`  [INFERRED]
  pc/screen-link/tests/test_protocol.py → pc/screen-link/src/m5_screen_link/protocol.py

## Import Cycles
- None detected.

## Communities (32 total, 7 thin omitted)

### Community 0 - "common.sh"
Cohesion: 0.08
Nodes (46): audit-public-tree.sh script, read_flash_piece(), backup-flash.sh script, build-ci-target.sh script, build-matrix.sh script, build.sh script, IDF_TOOLS_PATH, build-stackchan-factory.sh script (+38 more)

### Community 1 - "server.py"
Cohesion: 0.08
Nodes (36): Application, ArgumentParser, FileResponse, IntEnum, PC screen relay for M5Stack devices., pack_stackchan_packet(), parse_producer_frame(), ProtocolError (+28 more)

### Community 2 - "index.md"
Cohesion: 0.13
Nodes (13): ESP32 GitHubプロジェクトの見方, 分野別一覧, 導入前チェック, 目的から選ぶ, Arduino経路, K151向けカスタムファームウェア, OSSとバージョンの選定, 公式ファームウェア経路 (+5 more)

### Community 3 - "詳しい使い方"
Cohesion: 0.12
Nodes (16): 10. シリアルログを見る, 11. Arduino確認スケッチを書き込む, 12. 全Flashを復旧する, 13. 日常の開発サイクル, 1. リポジトリを準備する, 2. USB接続を確認する, 3. 実機をローカル設定へ固定する, 4. Arduino環境を導入する (+8 more)

### Community 4 - "Stack-chanコミュニティ版の導入・使い方"
Cohesion: 0.22
Nodes (9): 2026-08-01の実機確認, MODを試す, Stack-chanコミュニティ版の導入・使い方, できること, 初回Wi-Fi設定, 工場版へ戻す, 方法A: 配布元Web Installer, 方法B: 固定版をCLIで検証して書き込む (+1 more)

### Community 5 - "app.js"
Cohesion: 0.33
Nodes (11): clamp(), drawContained(), elements, encodeTarget(), frameLoop(), jpegBlob(), setStatus(), start() (+3 more)

### Community 6 - "M5Stackとマイコンの全体像"
Cohesion: 0.18
Nodes (11): Cardputer-AdvとCardputerZeroは別物, Cardputer-Advに最初からあるもの, GitHubで見かけるリポジトリの分類, M5Stackとマイコンの全体像, M5Stackの製品名, おすすめの学習順, よく出る通信方式, 主な一次資料 (+3 more)

### Community 7 - "m5stack"
Cohesion: 0.20
Nodes (10): host PCから画面リンクを操作する, m5stack, PC画面リンク（試験実装）, コマンド, ドキュメント, ライセンス, 三つの開発経路, 実機を操作する前に (+2 more)

### Community 8 - "2026-08-01"
Cohesion: 0.13
Nodes (15): 2026-07-31, 2026-08-01, 2026-08-01 my-m5docs最終統合, CardputerミュートとMarkdownサイト, OSSカスタムファームウェア調査, OSS調査, v1.0.0書込みと起動確認, バックアップと復旧経路 (+7 more)

### Community 9 - "Cardputer Adv PC画面リンク"
Cohesion: 0.40
Nodes (4): Cardputer Adv PC画面リンク, 操作, 設定とビルド, 音をmuteする

### Community 10 - "PC Screen Link relay"
Cohesion: 0.40
Nodes (4): PC Screen Link relay, セキュリティ, プロトコル, 起動

### Community 11 - "StackChan PC画面リンク"
Cohesion: 0.40
Nodes (4): StackChan PC画面リンク, 使い方, 対応ファームウェア, 設定とビルド

### Community 12 - "test-common.sh"
Cohesion: 0.40
Nodes (4): M5_BY_ID_ROOT, M5_DEV_ROOT, M5_ENV_FILE, M5_SYSFS_ROOT

### Community 14 - "PC画面をCardputer／StackChanへ送る"
Cohesion: 0.25
Nodes (8): 1. PC relayを設定する, 2. Cardputer Advを準備する, 3. StackChanを準備する, PC画面をCardputer／StackChanへ送る, できること, セキュリティと制約, 接続状態を確認する, 詳細

### Community 15 - "安全な実機ワークフロー"
Cohesion: 0.22
Nodes (9): 0. 物理安全, 1. 書込みを伴わない準備, 2. ポート権限, 3. 工場出荷Flashの保存, 4. シリアル監視, 5. Arduinoスケッチの書込み, 6. Stack-chanコミュニティ版, 7. 公式ファームウェア (+1 more)

### Community 22 - "Cardputer-Advをミュートする"
Cohesion: 0.25
Nodes (8): 3.5 mm端子, Bruce 1.16の場合, Cardputer-Advをミュートする, 何が静かになるか, 参照した公式情報, 最短手順, 根拠と、以前の説明が違った理由, 自作ファームウェアで完全に消音する

### Community 23 - "ハードウェア調査記録"
Cohesion: 0.29
Nodes (7): 2026-07-31のUSB Hub観測の訂正, 2026-08-01の対象分離後の観測, Cardputer Advについて, Flash読出しと書込み, ハードウェア調査記録, 接続の安定性, 結論

### Community 24 - "my-m5docs"
Cohesion: 0.29
Nodes (7): Cardputer, my-m5docs, PC画面リンク, StackChan, まず読む, 依存関係と選定根拠, 記録の読み方

### Community 25 - "復旧とUSBトラブル対応"
Cohesion: 0.33
Nodes (6): Download Mode, まず切り分ける, セキュリティ機能が有効な場合, バックアップがない場合, 全Flashバックアップからの復旧, 復旧とUSBトラブル対応

### Community 26 - "Bruce 1.16とCardputer-Adv"
Cohesion: 0.25
Nodes (8): Bruce 1.16とCardputer-Adv, Bruceでミュートする, Cardputer-Adv対応の根拠, 内蔵だけで使えるものと外付けが必要なもの, 参照先, 導入を判断する前の安全確認, 確認した版と配布物, 結論

### Community 28 - "Cardputer-Advの基本的な使い方"
Cohesion: 0.25
Nodes (8): Cardputer-Advの基本的な使い方, PCやスマートフォンのキーボードとして使う, どんな機器か, キーボード早見表, 公式UserDemo, 公式資料, 工場ファームウェアへ戻す, 電源、充電、G0

### Community 29 - "Cardputerコミュニティソフトの見方"
Cohesion: 0.29
Nodes (7): awesome listは仕様書ではない, Cardputer-Adv対応を見分ける, Cardputerコミュニティソフトの見方, 初心者が優先するもの, 参照先, 導入前チェック, 掲載内容の分類

### Community 30 - "StackChan公式ファームウェアの再現ビルド"
Cohesion: 0.33
Nodes (6): StackChan公式ファームウェアの再現ビルド, ビルド, 初回セットアップ, 方針, 書込みを自動化しない理由, 設定overlay

### Community 31 - "main"
Cohesion: 0.80
Nodes (4): links_outside_fences(), local_target(), main(), Path

## Knowledge Gaps
- **151 isolated node(s):** `build.sh script`, `m5-screen-link`, `run.sh script`, `targetIds`, `targetSizes` (+146 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `詳しい使い方` connect `詳しい使い方` to `index.md`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `作業記録` connect `2026-08-01` to `index.md`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `M5Stackとマイコンの全体像` connect `M5Stackとマイコンの全体像` to `index.md`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **What connects `build.sh script`, `m5-screen-link`, `run.sh script` to the rest of the system?**
  _151 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `common.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.07668231611893583 - nodes in this community are weakly interconnected._
- **Should `server.py` be split into smaller, more focused modules?**
  _Cohesion score 0.08051948051948052 - nodes in this community are weakly interconnected._
- **Should `index.md` be split into smaller, more focused modules?**
  _Cohesion score 0.13333333333333333 - nodes in this community are weakly interconnected._