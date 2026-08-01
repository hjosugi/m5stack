# Graph Report - m5stack  (2026-08-01)

## Corpus Check
- 52 files · ~10,072 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 298 nodes · 511 edges · 27 communities (19 shown, 8 thin omitted)
- Extraction: 93% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 38 edges (avg confidence: 0.51)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b8965336`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- common.sh
- server.py
- index.md
- 詳しい使い方
- Stack-chanコミュニティ版の導入・使い方
- app.js
- ServerTest
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
- Cardputerをミュートする
- ハードウェア調査記録
- my-m5docs
- 復旧とUSBトラブル対応
- test-taskfile.sh

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
10. `ServerTest` - 10 edges

## Surprising Connections (you probably didn't know these)
- `ServerTest` --uses--> `Target`  [INFERRED]
  pc/screen-link/tests/test_server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `ServerTest` --uses--> `StackChanType`  [INFERRED]
  pc/screen-link/tests/test_server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `test-common.sh script` --calls--> `load_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `write_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `detect_m5_usb()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh

## Import Cycles
- None detected.

## Communities (27 total, 8 thin omitted)

### Community 0 - "common.sh"
Cohesion: 0.08
Nodes (46): audit-public-tree.sh script, read_flash_piece(), backup-flash.sh script, build-ci-target.sh script, build-matrix.sh script, build.sh script, IDF_TOOLS_PATH, build-stackchan-factory.sh script (+38 more)

### Community 1 - "server.py"
Cohesion: 0.10
Nodes (35): Application, ArgumentParser, FileResponse, IntEnum, Path, PC screen relay for M5Stack devices., pack_stackchan_packet(), parse_producer_frame() (+27 more)

### Community 2 - "index.md"
Cohesion: 0.12
Nodes (15): Arduino経路, K151向けカスタムファームウェア, OSSとバージョンの選定, 公式ファームウェア経路, 再現性と安全性の境界, StackChan公式ファームウェアの再現ビルド, ビルド, 初回セットアップ (+7 more)

### Community 3 - "詳しい使い方"
Cohesion: 0.12
Nodes (16): 10. シリアルログを見る, 11. Arduino確認スケッチを書き込む, 12. 全Flashを復旧する, 13. 日常の開発サイクル, 1. リポジトリを準備する, 2. USB接続を確認する, 3. 実機をローカル設定へ固定する, 4. Arduino環境を導入する (+8 more)

### Community 4 - "Stack-chanコミュニティ版の導入・使い方"
Cohesion: 0.22
Nodes (9): 2026-08-01の実機確認, MODを試す, Stack-chanコミュニティ版の導入・使い方, できること, 初回Wi-Fi設定, 工場版へ戻す, 方法A: 配布元Web Installer, 方法B: 固定版をCLIで検証して書き込む (+1 more)

### Community 5 - "app.js"
Cohesion: 0.33
Nodes (11): clamp(), drawContained(), elements, encodeTarget(), frameLoop(), jpegBlob(), setStatus(), start() (+3 more)

### Community 7 - "m5stack"
Cohesion: 0.20
Nodes (10): host PCから画面リンクを操作する, m5stack, PC画面リンク（試験実装）, コマンド, ドキュメント, ライセンス, 三つの開発経路, 実機を操作する前に (+2 more)

### Community 8 - "2026-08-01"
Cohesion: 0.14
Nodes (14): 2026-07-31, 2026-08-01, CardputerミュートとMarkdownサイト, OSSカスタムファームウェア調査, OSS調査, v1.0.0書込みと起動確認, バックアップと復旧経路, 作業記録 (+6 more)

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

### Community 22 - "Cardputerをミュートする"
Cohesion: 0.29
Nodes (7): Cardputer AdvのAUXについて, Cardputerをミュートする, 「ミュート」の対象を分ける, 公式UserDemoで設定できない根拠, 参照した公式情報, 結論, 自作ファームウェアへ画面設定を追加する

### Community 23 - "ハードウェア調査記録"
Cohesion: 0.29
Nodes (7): 2026-07-31のUSB Hub観測の訂正, 2026-08-01の対象分離後の観測, Cardputer Advについて, Flash読出しと書込み, ハードウェア調査記録, 接続の安定性, 結論

### Community 24 - "my-m5docs"
Cohesion: 0.29
Nodes (7): Cardputer, my-m5docs, PC画面リンク, StackChan, まず読む, 依存関係と選定根拠, 記録の読み方

### Community 25 - "復旧とUSBトラブル対応"
Cohesion: 0.33
Nodes (6): Download Mode, まず切り分ける, セキュリティ機能が有効な場合, バックアップがない場合, 全Flashバックアップからの復旧, 復旧とUSBトラブル対応

## Knowledge Gaps
- **116 isolated node(s):** `build.sh script`, `m5-screen-link`, `run.sh script`, `targetIds`, `targetSizes` (+111 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `詳しい使い方` connect `詳しい使い方` to `index.md`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `作業記録` connect `2026-08-01` to `index.md`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Why does `m5stack` connect `m5stack` to `index.md`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **What connects `build.sh script`, `m5-screen-link`, `run.sh script` to the rest of the system?**
  _116 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `common.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.07668231611893583 - nodes in this community are weakly interconnected._
- **Should `server.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0975177304964539 - nodes in this community are weakly interconnected._
- **Should `index.md` be split into smaller, more focused modules?**
  _Cohesion score 0.12433862433862433 - nodes in this community are weakly interconnected._