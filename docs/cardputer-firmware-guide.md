# Cardputer-Adv firmware構成

## 採用構成

2026-08-01に版、Cardputer-Adv対応、配布物を再確認し、次の構成に固定しました。

```text
本体: M5Launcher 2.8.0
└── メイン: Bruce 1.16

microSDに保管:
├── Picoware v2.1.0
├── Factory UserDemo ADV-V0.3
├── UIFlow2 Cardputer-Adv v2.5.0
├── Cardputer Game Station v1.2
└── Meshtastic v2.7.26.54e0d8d
```

普段はBruceを自動起動し、別用途だけM5Launcherへ戻ってSD上のfirmwareへ入れ替えます。Cardputer-AdvのFlashは8 MBなので、この6種類をすべて同時常駐させる構成ではありません。M5LauncherはOSではなく、Flash上のapp・data partition、SD上のbinary、online catalogを管理するlauncherです。

## 先に訂正する版番号

提示された比較ではM5Launcher 2.7.2を最新版としていましたが、2026-07-31 15:19 UTCに2.8.0が公開されています。日本時間では2026-08-01 00:19です。

| 項目 | 確認値 |
| --- | --- |
| M5Launcher release | [`2.8.0`](https://github.com/bmorcelli/Launcher/releases/tag/2.8.0) |
| tag commit | `415033574e968a1fd58361c17d26f57832577423` |
| Cardputer asset | `Launcher-m5stack-cardputer.bin` |
| size | 1,401,280 bytes |
| SHA-256 | `308c11982fd7260f535c4fe1f999c3cd4e13b649cd27a29b0cbeb2064f35483e` |
| Bruce stable release | [`1.16`](https://github.com/BruceDevices/firmware/releases/tag/1.16) |

M5Launcher 2.8.0の配布assetを実際に取得し、GitHub Release APIのdigestと同じSHA-256になることを確認しました。CardputerとADVは同じassetを使い、起動時にTCA8418の有無を判定します。

2.8.0ではkeyboard shortcut、fast boot、download済みfirmwareの更新確認、multi-part binary処理、data partition backup対応等が加わりました。2.7系で導入されたdynamic partition管理、複数firmware、暗号化Wi-Fi設定も引き継いでいます。

## 配布物と照合値

microSDへ置く実体は次の通りです。SHA-256は2026-08-01に実際に取得したファイルで照合しました。

| 用途 | 版 | microSD上の名前 | size | SHA-256 |
| --- | --- | --- | ---: | --- |
| 起動基盤 | M5Launcher 2.8.0 | `M5Launcher-2.8.0.bin` | 1,401,280 | `308c11982fd7260f535c4fe1f999c3cd4e13b649cd27a29b0cbeb2064f35483e` |
| メイン | Bruce 1.16 | `Bruce-1.16.bin` | 4,153,760 | `a0e1346db08fdfe7adf4a8f206530fc9ed1a4e2f551d91512000d0a2889bee77` |
| PDA | Picoware v2.1.0 | `Picoware-2.1.0-Cardputer.bin` | 2,419,312 | `c81ed7670a244f892b79c27e941af4ed6bd9ba03dff77c36ce363e654cc580a2` |
| 純正確認 | UserDemo ADV-V0.3 | `Factory-UserDemo-ADV-V0.3.bin` | 2,690,480 | `7bb1532427c875445b16186b6139afa371f67ddbdc83ae5bfe4a9089c7883b74` |
| Python | UIFlow2 v2.5.0 | `UIFlow2-Cardputer-Adv-2.5.0.bin` | 8,384,512 | `1892a6da611308fcf8386ee80a1e425d47ce3ec246d2a99d79e46caec6a5734d` |
| game | Game Station v1.2 | `Game-Station-1.2.bin` | 2,686,576 | `cc6e14ea7d3688aabd2f958ef36c94c6ac37b9481bb523f1abfafa5ae281c7c8` |
| LoRa | Meshtastic v2.7.26.54e0d8d | `Meshtastic-Cardputer-Adv-2.7.26.54e0d8d.bin` | 2,226,320 | `bbe614bf9e9613891f53094c551daa3b1686f28ca67498713e14c9ad168205a8` |

Picowareの公式導入手順は、M5Launcherから`Picoware-Cardputer.bin`を選ぶ方法を案内しています。直接esptoolで書く場合だけは、同tagのbootloader、partition table、appをそれぞれ`0x0`、`0x8000`、`0x20000`へ書く必要があります。M5Launcherから使う本構成ではapp binaryをSDへ置き、`picoware/apps/`と`picoware/scripts/`も同じtagからコピーします。

## 主要firmware比較

| Firmware | 2026-08-01確認版 | ADV対応の根拠 | 得意分野 | 判断 |
| --- | --- | --- | --- | --- |
| M5Launcher | 2.8.0 | 同一Cardputer buildがTCA8418をruntime検出 | firmware・partition・backup管理 | 複数firmware利用の基盤 |
| Bruce | 1.16 | 同一binaryがTCA8418とES8311をruntime検出 | 多機能tool、認可済みsecurity検証 | 採用: メイン |
| Picoware | v2.1.0 | repoとreleaseがCardputer-ADVを明記 | editor、REPL、file、app、game | 採用: PDA |
| UIFlow2 | v2.5.0 | M5Burner catalogとM5Stack公式Cardputer-Adv手順 | Blockly、MicroPython、Unit／Cap制御 | 採用: 電子工作・Python |
| UserDemo | ADV-V0.3 | M5Stack公式ADV release | keyboard、audio、IR、Wi-Fi等の確認 | 採用: 純正復元・故障切分け |
| NEMO | v3.2.2 | releaseにM5Cardputer binary、READMEにADV機能を明記 | 絞ったsecurity学習 | Bruceより単純だが許可範囲必須 |
| Poseidon | v0.6.8 | Cardputer-Adv専用community firmware | 外付けRF、LoRa、security実験 | 実験的。重要認証には使わない |
| MicroHydra | v2.6-preview | releaseがADVのpartial supportと明記 | MicroPython app switcher | stable待ち |
| CircuitPython | 10.2.1 | 公式boardは初代Cardputer用 | Python library資産 | ADV keyboardの正式統合待ち |
| Game Station | v1.2 | release assetとADV向けinput処理を確認 | 複数console emulator | 採用: game |
| MeshCore client | v1.15.81 | ADV専用community release | MeshCore message端末 | MeshCore利用者向け |
| Meshtastic | v2.7.26.54e0d8d | upstream manifestが`m5stack-cardputer-adv`を収録 | LoRa mesh、位置・telemetry | 採用: Cap LoRa-1262使用時だけ |

NEMO、Poseidon、MicroHydra、CircuitPython、MeshCoreは比較のために調べた未採用候補です。用途や対応networkを変えない限り、上の採用構成へ追加しません。

## 用途別の選択

| 目的 | 第一候補 | 理由 |
| --- | --- | --- |
| 複数firmwareの切替 | M5Launcher 2.8.0 | app・data partitionとSD／online binaryをまとめて扱える |
| 多機能tool | Bruce 1.16 | ADV keyboard・audio対応がsourceで確認できる |
| PDA・mini computer風 | Picoware v2.1.0 | file、editor、REPL、appを中心に設計 |
| Python・sensor制作 | UIFlow2 | M5Stack公式driverとBlockly／MicroPython |
| 純正状態・hardware確認 | UserDemo CardputerADV | 公式hardware demoとfactory復元経路 |
| game | Game Station v1.2 | 多数のemulatorを一つに統合 |
| LoRa mesh | 公式Meshtastic | Cardputer Mesh Kitの公式手順がある |
| MeshCore | meshcore-cardputer-adv | ADV専用community client |

## microSDの配置

SDHC、最大32 GB、MBR、FAT32を使います。SDXCやGPTのカードは避けます。

```text
/
├── SHA256SUMS
├── firmware/
│   ├── M5Launcher-2.8.0.bin
│   ├── Bruce-1.16.bin
│   ├── Picoware-2.1.0-Cardputer.bin
│   ├── Factory-UserDemo-ADV-V0.3.bin
│   ├── UIFlow2-Cardputer-Adv-2.5.0.bin
│   ├── Game-Station-1.2.bin
│   └── Meshtastic-Cardputer-Adv-2.7.26.54e0d8d.bin
├── picoware/
│   ├── apps/
│   └── scripts/
└── roms/
```

game ROMは権利を持つdumpだけを非圧縮で`roms/`へ置きます。本リポジトリやPagesではROM、firmware binary、Flash dumpを配布しません。

## Bruceをメインにする

1. M5Launcher起動中に`SD`を開く。
2. `firmware/Bruce-1.16.bin`を選び、`Install`を実行する。
3. 完了後にBruceが起動することを確認する。
4. 以後はboot画面で何も押さず、最後にinstallしたBruceを起動する。
5. 別firmwareへ切り替える時だけ、boot画面でキーを押してLauncherへ入り、SDから選ぶ。

Launcher自身のOTAで取得する場合は、直接installせず`Download -> SD`を選ぶと`/downloads/`へ保存されます。2.8.0は`downloaded.json`で更新を追跡し、multi-part配布物をSD上の一つのinstall用binaryへまとめます。

## M5Launcherを使う時の注意

- SD cardへbinaryを保存できても、実行app本体はFlash partitionへinstallされる。8 MB Flashへ無制限に同居できるわけではない。
- firmwareごとにapp sizeとdata partition方式が異なる。自動判定結果を読み、partition変更前にbackupする。
- Picowareの元partitionは大きなFAT `vfs`を持つが、Launcherの動的配置では同じ容量が維持されない場合がある。初回は重要fileを置かずに起動と保存容量を確認し、不足時はPManでdata partitionを調整する。
- UIFlow2やGame Stationは大きいapp・data領域を必要とする。Launcherが提示する専用partition構成を確認してから切り替える。
- M5Launcherの設定は、起動先firmwareのWi-Fi、audio、key設定を一括変更しない。
- 2.8.0のdefault WebUI credentialを使い続けず、信頼できないnetworkではWebUIを公開しない。
- installer、M5Burner、Web FlasherはいずれもFlashを変更する。公式factory復元を先に用意する。

## Python系の判断

MicroHydraのstableはv2.5.1で、ADV対応が入ったv2.6はpreviewかつpartial supportです。CircuitPython 10.2.1には`m5stack_cardputer` boardがありますが、keyboard実装は初代のdirect GPIO matrix用です。ADVのTCA8418はPythonで操作するcommunity workaroundがある段階で、標準REPL keyboardとしての専用ADV buildは確認できませんでした。

現時点でCardputer-AdvのPythonを優先するなら、M5Stack公式UIFlow2か、ADVを対象にするPicowareを先に検討します。

## LoRa系の判断

公式Cardputer Mesh KitはCardputer-AdvとCap LoRa-1262の組合せです。M5Stack公式手順では、Flash時にCapを外し、起動前にアンテナを装着するよう案内しています。アンテナなしでLoRa送信機を通電しません。地域に対応する周波数・region設定を選びます。本構成ではMeshtastic upstreamのCardputer-Adv targetを使います。

MeshCoreはMeshtasticとは別networkです。利用するnetworkに合わせてfirmwareを選び、互換だと仮定しません。

## Security firmwareの境界

Bruce、NEMO、Poseidon、Marauder、Evil系は一般utilityだけでなく、Wi-Fi、BLE、USB HID、RFのsecurity試験機能を含みます。所有・管理している機器、または明示的な許可を得た環境だけで使用します。

Poseidon v0.6.8は自作FIDO2機能を掲げていますが、独立したsecurity auditを確認していません。重要なGoogle・GitHub等の本番accountを守る唯一のsecurity keyとしては採用しません。

## 参照先

- [M5Launcher 2.8.0](https://github.com/bmorcelli/Launcher/releases/tag/2.8.0)
- [M5Launcherの仕組み](https://github.com/bmorcelli/Launcher/wiki/Explaining-the-project)
- [Bruce 1.16](https://github.com/BruceDevices/firmware/releases/tag/1.16)
- [Picoware v2.1.0](https://github.com/jblanked/Picoware/releases/tag/v2.1.0)
- [Picoware Cardputer-Adv導入手順](https://github.com/jblanked/Picoware/blob/v2.1.0/guides/Installation.md)
- [Cardputer-Adv UIFlow2公式手順](https://docs.m5stack.com/en/uiflow2/cardputer-adv/program)
- [公式UserDemo ADV-V0.3](https://github.com/m5stack/M5Cardputer-UserDemo/releases/tag/ADV-V0.3)
- [NEMO v3.2.2](https://github.com/n0xa/m5stick-nemo/releases/tag/v3.2.2)
- [Poseidon v0.6.8](https://github.com/GeneralDussDuss/poseidon/releases/tag/v0.6.8)
- [MicroHydra v2.6-preview](https://github.com/echo-lalia/MicroHydra/releases/tag/v2.6-preview)
- [CircuitPython ADV keyboard issue](https://github.com/adafruit/circuitpython/issues/10765)
- [Cardputer Game Station v1.2](https://github.com/geo-tp/Cardputer-Game-Station-Emulators/releases/tag/v1.2)
- [Meshtastic v2.7.26.54e0d8d](https://github.com/meshtastic/firmware/releases/tag/v2.7.26.54e0d8d)
- [MeshCore Cardputer ADV v1.15.81](https://github.com/sosprz/meshcore-cardputer-adv/releases/tag/v1.15.81)
- [Cardputer Mesh Kit公式Meshtastic手順](https://docs.m5stack.com/en/guide/lora/meshtastic/cardputer_mesh_kit)
- [Cardputer-Adv factory復元](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)

確認日以後にreleaseやcatalogは更新されます。`最新版`という語だけを保存せず、導入時のtag、asset名、digest、確認日を記録してください。
