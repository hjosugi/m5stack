# Graph Report - docs-css-tokens  (2026-08-01)

## Corpus Check
- 48 files · ~10,016 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 261 nodes · 454 edges · 28 communities (20 shown, 8 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 37 edges (avg confidence: 0.51)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f2634ba9`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- die
- server.py
- README.md
- 詳しい使い方
- PageParser
- app.js
- ServerTest
- m5stack
- 2026-07-31
- Cardputer Adv PC画面リンク
- PC Screen Link relay
- StackChan PC画面リンク
- test-common.sh
- cardputer/screen-link/build.sh
- log
- 安全な実機ワークフロー
- screen_link_auth.cpp
- test-safety-gates.sh
- run.sh
- stackchan/screen-link/build.sh
- m5-screen-link
- common.sh
- setup.sh script
- detect_m5_usb
- build-stackchan-factory.sh script
- select-board.sh script
- test-taskfile.sh

## God Nodes (most connected - your core abstractions)
1. `die()` - 25 edges
2. `log()` - 20 edges
3. `require_command()` - 17 edges
4. `詳しい使い方` - 15 edges
5. `Target` - 12 edges
6. `create_app()` - 12 edges
7. `load_local_env()` - 12 edges
8. `FrameHub` - 11 edges
9. `upload.sh script` - 11 edges
10. `ServerTest` - 10 edges

## Surprising Connections (you probably didn't know these)
- `test-common.sh script` --calls--> `load_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `ServerTest` --uses--> `Target`  [INFERRED]
  pc/screen-link/tests/test_server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `ServerTest` --uses--> `StackChanType`  [INFERRED]
  pc/screen-link/tests/test_server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `test-common.sh script` --calls--> `write_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `detect_m5_usb()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh

## Import Cycles
- None detected.

## Communities (28 total, 8 thin omitted)

### Community 0 - "die"
Cohesion: 0.42
Nodes (13): backup-flash.sh script, grant-port-access.sh script, die(), load_local_env(), require_command(), require_model_config(), require_port_access(), verify_bound_device() (+5 more)

### Community 1 - "server.py"
Cohesion: 0.10
Nodes (35): Application, ArgumentParser, FileResponse, IntEnum, PC screen relay for M5Stack devices., pack_stackchan_packet(), parse_producer_frame(), ProtocolError (+27 more)

### Community 2 - "README.md"
Cohesion: 0.07
Nodes (26): 2026-07-31の非破壊観測, Cardputer Advについて, この時点で行っていない操作, ハードウェア調査記録, 接続の安定性, 結論, Arduino経路, OSSとバージョンの選定 (+18 more)

### Community 3 - "詳しい使い方"
Cohesion: 0.13
Nodes (15): 10. Arduino確認スケッチを書き込む, 11. 全Flashを復旧する, 12. 日常の開発サイクル, 1. リポジトリを準備する, 2. USB接続を確認する, 3. 実機をローカル設定へ固定する, 4. Arduino環境を導入する, 5. Arduinoスケッチをビルドする (+7 more)

### Community 4 - "PageParser"
Cohesion: 0.25
Nodes (8): HTMLParser, main(), PageParser, parse_pages(), Path, resolve_local_target(), validate_links(), validate_styles()

### Community 5 - "app.js"
Cohesion: 0.33
Nodes (11): clamp(), drawContained(), elements, encodeTarget(), frameLoop(), jpegBlob(), setStatus(), start() (+3 more)

### Community 7 - "m5stack"
Cohesion: 0.20
Nodes (10): host PCから画面リンクを操作する, m5stack, PC画面リンク（試験実装）, コマンド, ドキュメント, ライセンス, 二つの開発経路, 実機を操作する前に (+2 more)

### Community 8 - "2026-07-31"
Cohesion: 0.25
Nodes (7): 2026-07-31, OSS調査, 作業記録, 安全確認, 実装, 対象確定, 検証と公開

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

### Community 14 - "log"
Cohesion: 0.18
Nodes (8): audit-public-tree.sh script, check.sh script, checkout_exact(), fetch-stackchan.sh script, log(), IDF_TOOLS_PATH, setup-stackchan-factory.sh script, verify-stackchan-upstream.sh script

### Community 15 - "安全な実機ワークフロー"
Cohesion: 0.25
Nodes (8): 0. 物理安全, 1. 書込みを伴わない準備, 2. ポート権限, 3. 工場出荷Flashの保存, 4. シリアル監視, 5. Arduinoスケッチの書込み, 6. 公式ファームウェア, 安全な実機ワークフロー

### Community 22 - "common.sh"
Cohesion: 0.18
Nodes (3): device_hash(), hash_identifier(), common.sh script

### Community 23 - "setup.sh script"
Cohesion: 0.25
Nodes (7): build-ci-target.sh script, build-matrix.sh script, build.sh script, arduino_cli(), configure_arduino_env(), install_library(), setup.sh script

### Community 24 - "detect_m5_usb"
Cohesion: 0.29
Nodes (6): detect-device.sh script, init-env.sh script, detect_m5_usb(), usb_id_is_supported(), write_local_env(), test-common.sh script

### Community 25 - "build-stackchan-factory.sh script"
Cohesion: 0.40
Nodes (3): IDF_TOOLS_PATH, build-stackchan-factory.sh script, assert_exact_git_checkout()

### Community 26 - "select-board.sh script"
Cohesion: 0.67
Nodes (3): lookup_board_key(), select-board.sh script, usage()

## Knowledge Gaps
- **79 isolated node(s):** `build.sh script`, `m5-screen-link`, `run.sh script`, `targetIds`, `targetSizes` (+74 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `詳しい使い方` connect `詳しい使い方` to `README.md`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Why does `m5stack` connect `m5stack` to `README.md`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `安全な実機ワークフロー` connect `安全な実機ワークフロー` to `README.md`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Target` (e.g. with `FrameHub` and `ProtocolTest`) actually correct?**
  _`Target` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `m5-screen-link`, `run.sh script` to the rest of the system?**
  _79 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `server.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0975177304964539 - nodes in this community are weakly interconnected._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.0659536541889483 - nodes in this community are weakly interconnected._