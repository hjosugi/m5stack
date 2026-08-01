# Graph Report - pc-screen-link  (2026-08-01)

## Corpus Check
- 45 files · ~8,748 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 253 nodes · 439 edges · 22 communities (13 shown, 9 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 35 edges (avg confidence: 0.51)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f8aa894f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- common.sh
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
- build-stackchan-factory.sh
- setup-stackchan-factory.sh
- screen_link_auth.cpp
- test-safety-gates.sh
- run.sh
- stackchan/screen-link/build.sh
- m5-screen-link

## God Nodes (most connected - your core abstractions)
1. `die()` - 23 edges
2. `log()` - 19 edges
3. `require_command()` - 15 edges
4. `詳しい使い方` - 15 edges
5. `Target` - 12 edges
6. `create_app()` - 12 edges
7. `load_local_env()` - 12 edges
8. `FrameHub` - 11 edges
9. `upload.sh script` - 11 edges
10. `ServerTest` - 10 edges

## Surprising Connections (you probably didn't know these)
- `ServerTest` --uses--> `Target`  [INFERRED]
  pc/screen-link/tests/test_server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `ServerTest` --uses--> `StackChanType`  [INFERRED]
  pc/screen-link/tests/test_server.py → pc/screen-link/src/m5_screen_link/protocol.py
- `setup-stackchan-factory.sh script` --calls--> `log()`  [EXTRACTED]
  scripts/setup-stackchan-factory.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `load_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh
- `test-common.sh script` --calls--> `write_local_env()`  [EXTRACTED]
  tests/test-common.sh → scripts/lib/common.sh

## Import Cycles
- None detected.

## Communities (22 total, 9 thin omitted)

### Community 0 - "common.sh"
Cohesion: 0.10
Nodes (38): audit-public-tree.sh script, backup-flash.sh script, build-matrix.sh script, build.sh script, build-stackchan-factory.sh script, check.sh script, detect-device.sh script, checkout_exact() (+30 more)

### Community 1 - "server.py"
Cohesion: 0.10
Nodes (35): Application, ArgumentParser, FileResponse, IntEnum, PC screen relay for M5Stack devices., pack_stackchan_packet(), parse_producer_frame(), ProtocolError (+27 more)

### Community 2 - "README.md"
Cohesion: 0.05
Nodes (34): 2026-07-31の非破壊観測, Cardputer Advについて, この時点で行っていない操作, ハードウェア調査記録, 接続の安定性, 結論, Arduino経路, OSSとバージョンの選定 (+26 more)

### Community 3 - "詳しい使い方"
Cohesion: 0.13
Nodes (15): 10. Arduino確認スケッチを書き込む, 11. 全Flashを復旧する, 12. 日常の開発サイクル, 1. リポジトリを準備する, 2. USB接続を確認する, 3. 実機をローカル設定へ固定する, 4. Arduino環境を導入する, 5. Arduinoスケッチをビルドする (+7 more)

### Community 4 - "PageParser"
Cohesion: 0.26
Nodes (7): HTMLParser, main(), PageParser, parse_pages(), Path, resolve_local_target(), validate_links()

### Community 5 - "app.js"
Cohesion: 0.33
Nodes (11): clamp(), drawContained(), elements, frameLoop(), jpegBlob(), sendTarget(), setStatus(), start() (+3 more)

### Community 7 - "m5stack"
Cohesion: 0.22
Nodes (9): m5stack, PC画面リンク（試験実装）, コマンド, ドキュメント, ライセンス, 二つの開発経路, 実機を操作する前に, 最短の安全な手順 (+1 more)

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

## Knowledge Gaps
- **78 isolated node(s):** `build.sh script`, `m5-screen-link`, `run.sh script`, `targetIds`, `targetSizes` (+73 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `詳しい使い方` connect `詳しい使い方` to `README.md`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **Why does `m5stack` connect `m5stack` to `README.md`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Target` (e.g. with `FrameHub` and `ProtocolTest`) actually correct?**
  _`Target` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `m5-screen-link`, `run.sh script` to the rest of the system?**
  _78 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `common.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.10025062656641603 - nodes in this community are weakly interconnected._
- **Should `server.py` be split into smaller, more focused modules?**
  _Cohesion score 0.09990749306197964 - nodes in this community are weakly interconnected._
- **Should `README.md` be split into smaller, more focused modules?**
  _Cohesion score 0.05226480836236934 - nodes in this community are weakly interconnected._