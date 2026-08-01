# Cardputer-Adv firmware選定

## 結論

複数firmwareを使い分けたい場合の基盤は[M5Launcher 2.8.0](https://github.com/bmorcelli/Launcher/releases/tag/2.8.0)、一つの多機能firmwareを選ぶ場合は[Bruce 1.16](https://github.com/BruceDevices/firmware/releases/tag/1.16)が有力です。

```text
M5Launcher 2.8.0
├── 多機能・許可済みsecurity検証: Bruce 1.16
├── PDA・file・code: Picoware v2.1.0
├── Python・電子工作: 公式UIFlow2
├── 純正hardware確認: 公式UserDemo CardputerADV
└── game: Cardputer Game Station v1.2
```

これは万人向けの絶対順位ではありません。M5LauncherはOSではなく、Flash上のapp・data partition、SD上のbinary、online catalogを管理するlauncherです。Bruceはsecurity試験機能を多く含むため、日常PDAが目的ならPicoware、電子工作ならUIFlow2の方が直接的です。

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

## 主要firmware比較

| Firmware | 2026-08-01確認版 | ADV対応の根拠 | 得意分野 | 判断 |
| --- | --- | --- | --- | --- |
| M5Launcher | 2.8.0 | 同一Cardputer buildがTCA8418をruntime検出 | firmware・partition・backup管理 | 複数firmware利用の基盤 |
| Bruce | 1.16 | 同一binaryがTCA8418とES8311をruntime検出 | 多機能tool、認可済みsecurity検証 | 一つだけなら総合候補 |
| Picoware | v2.1.0 | repoとreleaseがCardputer-ADVを明記 | editor、REPL、file、app、game | PDA用途候補 |
| UIFlow2 | M5Burnerで当日確認 | M5Stack公式Cardputer-Adv手順あり | Blockly、MicroPython、Unit／Cap制御 | 電子工作・Python向け |
| UserDemo | `CardputerADV` branch | M5Stack公式ADV専用source | keyboard、audio、IR、Wi-Fi等の確認 | 純正復元・故障切分け |
| NEMO | v3.2.2 | releaseにM5Cardputer binary、READMEにADV機能を明記 | 絞ったsecurity学習 | Bruceより単純だが許可範囲必須 |
| Poseidon | v0.6.8 | Cardputer-Adv専用community firmware | 外付けRF、LoRa、security実験 | 実験的。重要認証には使わない |
| MicroHydra | v2.6-preview | releaseがADVのpartial supportと明記 | MicroPython app switcher | stable待ち |
| CircuitPython | 10.2.1 | 公式boardは初代Cardputer用 | Python library資産 | ADV keyboardの正式統合待ち |
| Game Station | v1.2 | release assetとADV向けinput処理を確認 | 複数console emulator | game用途候補 |
| MeshCore client | v1.15.81 | ADV専用community release | MeshCore message端末 | MeshCore利用者向け |
| Meshtastic | M5Burnerで当日確認 | M5Stack公式Cardputer Mesh Kit手順 | LoRa mesh、位置・telemetry | 公式LoRa用途候補 |

`M5Burnerで当日確認`とした項目は、Web文書だけから変動するcatalog版番号を固定しません。install直前にM5Burner上のCardputer-Adv対象名、版、公開元を確認します。

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

## M5Launcherを使う時の注意

- SD cardへbinaryを保存できても、実行app本体はFlash partitionへinstallされる。8 MB Flashへ無制限に同居できるわけではない。
- firmwareごとにapp sizeとdata partition方式が異なる。自動判定結果を読み、partition変更前にbackupする。
- M5Launcherの設定は、起動先firmwareのWi-Fi、audio、key設定を一括変更しない。
- 2.8.0のdefault WebUI credentialを使い続けず、信頼できないnetworkではWebUIを公開しない。
- installer、M5Burner、Web FlasherはいずれもFlashを変更する。公式factory復元を先に用意する。

## muteできない時

M5LauncherからBruceを起動している場合も、muteはBruce内で設定します。

```text
Bruce
└── Config
    └── Audio Config
        └── Sound: OFF
```

`Q`は公式UserDemo CardputerADVのlauncherだけの操作です。詳細なkey操作と、音が残る場合の確認は[Cardputer-Advをミュートする](cardputer-mute.md)を参照してください。

## Python系の判断

MicroHydraのstableはv2.5.1で、ADV対応が入ったv2.6はpreviewかつpartial supportです。CircuitPython 10.2.1には`m5stack_cardputer` boardがありますが、keyboard実装は初代のdirect GPIO matrix用です。ADVのTCA8418はPythonで操作するcommunity workaroundがある段階で、標準REPL keyboardとしての専用ADV buildは確認できませんでした。

現時点でCardputer-AdvのPythonを優先するなら、M5Stack公式UIFlow2か、ADVを対象にするPicowareを先に検討します。

## LoRa系の判断

公式Cardputer Mesh KitはCardputer-AdvとCap LoRa-1262の組合せです。M5Stack公式手順では、Flash時にCapを外し、起動前にアンテナを装着するよう案内しています。アンテナなしでLoRa送信機を通電しません。地域に対応する周波数・region設定を選びます。

MeshCoreはMeshtasticとは別networkです。利用するnetworkに合わせてfirmwareを選び、互換だと仮定しません。

## Security firmwareの境界

Bruce、NEMO、Poseidon、Marauder、Evil系は一般utilityだけでなく、Wi-Fi、BLE、USB HID、RFのsecurity試験機能を含みます。所有・管理している機器、または明示的な許可を得た環境だけで使用します。

Poseidon v0.6.8は自作FIDO2機能を掲げていますが、独立したsecurity auditを確認していません。重要なGoogle・GitHub等の本番accountを守る唯一のsecurity keyとしては採用しません。

## 参照先

- [M5Launcher 2.8.0](https://github.com/bmorcelli/Launcher/releases/tag/2.8.0)
- [M5Launcherの仕組み](https://github.com/bmorcelli/Launcher/wiki/Explaining-the-project)
- [Bruce 1.16](https://github.com/BruceDevices/firmware/releases/tag/1.16)
- [Picoware v2.1.0](https://github.com/jblanked/Picoware/releases/tag/v2.1.0)
- [Cardputer-Adv UIFlow2公式手順](https://docs.m5stack.com/en/uiflow2/cardputer-adv/program)
- [公式UserDemo CardputerADV](https://github.com/m5stack/M5Cardputer-UserDemo/tree/CardputerADV)
- [NEMO v3.2.2](https://github.com/n0xa/m5stick-nemo/releases/tag/v3.2.2)
- [Poseidon v0.6.8](https://github.com/GeneralDussDuss/poseidon/releases/tag/v0.6.8)
- [MicroHydra v2.6-preview](https://github.com/echo-lalia/MicroHydra/releases/tag/v2.6-preview)
- [CircuitPython ADV keyboard issue](https://github.com/adafruit/circuitpython/issues/10765)
- [Cardputer Game Station v1.2](https://github.com/geo-tp/Cardputer-Game-Station-Emulators/releases/tag/v1.2)
- [MeshCore Cardputer ADV v1.15.81](https://github.com/sosprz/meshcore-cardputer-adv/releases/tag/v1.15.81)
- [Cardputer Mesh Kit公式Meshtastic手順](https://docs.m5stack.com/en/guide/lora/meshtastic/cardputer_mesh_kit)
- [Cardputer-Adv factory復元](https://docs.m5stack.com/en/guide/restore_factory/cardputer_adv)

確認日以後にreleaseやcatalogは更新されます。`最新版`という語だけを保存せず、導入時のtag、asset名、digest、確認日を記録してください。
