# 作業記録

## 2026-08-01 Cardputer-Adv最新firmware構成

- 接続中のCardputer-Advだけを、既知のStackChanとは異なるUSB個体として固定した。Boot ROMでESP32-S3 revision v0.2、8 MB Flash、Secure Boot無効、Flash Encryption無効を確認した。
- 8 MB全Flash backupは64 KiB分割、4 KiB fallback、単一接続、115200／921600 baudで試したが、USB転送切断が再発して完成しなかった。不完全dumpは復旧用として扱わない。
- 代替復旧経路として公式Factory UserDemo ADV-V0.3を取得し、2,690,480 bytes、SHA-256 `7bb1532427c875445b16186b6139afa371f67ddbdc83ae5bfe4a9089c7883b74`を確認した。
- M5Launcher 2.8.0を`0x0`へ書き、esptoolの書込み後hash検証に成功した。USB経由ではDownload Modeを解除できなかったため、G0を押さない電源再投入後の通常起動確認を残している。
- Bruce 1.16、Picoware v2.1.0、UserDemo ADV-V0.3、UIFlow2 v2.5.0、Game Station v1.2、Meshtastic v2.7.26.54e0d8dを取得し、全binaryのSHA-256を照合した。Picowareの`apps`と`scripts`を含むmicroSD用treeを非公開`.local/`へ準備したが、PCにmicroSDが未接続なのでカードへのcopyはまだ行っていない。

## 2026-08-01 Cardputer mute再調査

- muteできない原因をfirmware差として再整理した。`Q`は公式UserDemo専用であり、Bruce 1.16では`Config` → `Audio Config` → `Sound: OFF`を使う。
- M5Launcherは2.7.2ではなく2.8.0が現行であることをRelease API、tag source、配布assetで確認した。
- M5Launcher 2.8.0のCardputer assetを取得し、1,401,280 bytes、SHA-256 `308c11982fd7260f535c4fe1f999c3cd4e13b649cd27a29b0cbeb2064f35483e`を確認した。この時点では調査だけで、実機書込みは上の作業へ分離した。
- Bruce、Picoware、UIFlow2、UserDemo、NEMO、Poseidon、MicroHydra、CircuitPython、Game Station、MeshCore、Meshtasticの版とADV対応根拠を再確認した。

## 2026-08-01 my-m5docs最終統合

- 既存GistのESP32 project調査を、安全境界と採否判断を加えたMarkdownとしてmy-m5docsへ統合した。
- Cardputer-Adv公式UserDemo、Bruce 1.16、Cardputer community softwareの調査を個別文書として収録した。
- StackChan画面リンク版を公開用仮値でbuildし、`stack-chan.bin`生成まで確認した。実機への書込みは行っていない。
- GitHub ActionsのTask一覧testがhuman-readable出力へ依存していたため、JSON出力による検証へ置き換えた。

## 2026-08-01

### CardputerミュートとMarkdownサイト

- 最初は通常の`main`ブランチだけを確認し、ADV版にも画面上のミュートがないと誤って判断した。
- 公式UserDemoの`CardputerADV`ブランチを再監査し、`Q`静音、消音アイコン、NVS保存を固定コミットで確認して文書を訂正した。
- 静音対象のランチャー効果音、静音対象外の`Record`再生、マイク停止、AUX切替を別の機能として整理した。
- Cardputer-Advの電源、充電、キーマップ、BLE／USB Keyboard、工場版復元を公式資料とソースから整理した。
- Bruce 1.16のADV自動検出、ES8311対応、内蔵／外付け機能、音設定を確認し、Release binのSHA-256を実測した。実機への書込みは行っていない。
- M5Stack、ESP32-S3、Cardputer-Adv、Arduino、公式libraryの関係を初心者向けに整理した。
- `awesome-m5stack-cardputer`を初代Cardputer中心の非公式索引として確認し、ADV対応を個別に判断する基準と安全な選び方を追加した。
- `docs/`の全Markdownを自動掲載し、日本語本文を検索できる最小構成のMkDocsサイトを追加した。
- Pagesではアプリやファームウェアを配布せず、調査文書の一覧、閲覧、検索だけを提供する方針にした。

### 対象USBの訂正と固定

- 外付けHubと別のESP32-S3をStackChan内部構成と関連付けた前日の判断を、公式回路図と物理的な抜き差しで訂正した。
- K151を単独接続し、最終対象を一台のCoreS3 native USBへ固定した。
- ESP32-S3 revision v0.2、16 MB Quad Flash、Secure Boot無効、Flash Encryption無効を確認した。
- 生USBシリアルは`.env`だけへ保存し、公開記録では短縮SHA-256のみを使用した。

### バックアップと復旧経路

- 16 MB全読出しを複数baudと1 MiB、64 KiB、4 KiBの分割で再試行した。
- USB転送停止が特定offset付近で再発し、完全な全Flashイメージは作成できなかった。
- スクリプトを、64 KiB読出し、4 KiB fallback、3回retry、不完全データ削除、marker非生成へ変更した。
- M5Stack公式文書からM5Burnerを取得し、配布ZIPとアプリ起動を確認して工場版復旧経路を確保した。

### OSSカスタムファームウェア調査

- GitHub上のK151/CoreS3候補についてREADME、Release、ライセンス、更新状況、書込み方法を比較した。
- K151標準構成、Apache-2.0、安定版Release、Web Installer、配布SHA-256、実機release gateが揃う`stack-chan/stack-chan` v1.0.0を選定した。
- AI会話、Home Assistant、ペット/API、PlatformIO系の候補は用途別の代替として記録した。

### v1.0.0書込みと起動確認

- GitHub Release ZIPのSHA-256を配布値と照合した。
- K151用bootloader/applicationがESP32-S3、16 MB、DIO、80 MHzで、イメージ内hashが有効であることを確認した。
- 配布元manifestどおり`0x0`、`0x8000`、`0x10000`へ書き込み、三領域すべての書込み後hash検証に成功した。
- 再起動後に同じ実機が再列挙され、起動ログでK151専用driver、PY32、サーボ電源、頭部touch、Stack-chan Voiceの初期化を確認した。
- Wi-Fi未設定を示すログは正常であり、認証情報を受け取らずBLE設定ページを開いた。

### 公開実装

- コミュニティ版v1.0.0のURLとSHA-256を固定した。
- 対象一台、復旧条件、security、image種別、offset、書込みhashを検証する明示許可付きinstallerを追加した。
- esptool出力からMAC、SerialNumber、`/dev/serial/by-id/`の実名を除去するtestを追加した。
- 詳細な導入、初回設定、MOD、工場版復旧、実機確認手順を追加した。

## 2026-07-31

### 対象確定

- ユーザー指定の公式`m5stack/StackChan`を主対象とした。
- 公式仕様でCoreS3、ESP32-S3、16 MB Flash、8 MB PSRAM、ロボット本体USB-Cのデータ接続を確認した。
- sysfsで外付けUSB Hub配下のEspressif native USBと`cdc_acm`を予備観測した。この関連付けは翌日の対象分離で訂正した。
- USB ID単独では型番を確定できないため、製品情報と実測の二つを分けて記録した。
- 生USBシリアル、購入情報、氏名、住所等はリポジトリへ記録していない。

### 安全確認

- シリアルポートを開かなかった。
- DTR/RTSを操作せず、実機をリセットしなかった。
- Flashの読出し、消去、書込みをしなかった。
- ポートが`root:uucp`の`0660`で、現在ユーザーにアクセス権がないことを確認した。
- 接続直後にUSB error `-71`とHubの再接続があったが、その後安定列挙したことを確認した。

### OSS調査

- M5Stack Board Manager、Arduino Library Manager、M5Stack公式GitHub、Espressif公式ESP-IDFを調査した。
- Arduinoと量産ファームウェアの二経路を分離した。
- StackChan、StackChan-BSP、ESP-IDF、量産ファームの外部依存を40桁commitで固定した。
- 公式ソースが配布済みファームより遅れる可能性を、Flashしない判断へ反映した。

### 実装

- Nix開発shellとArduinoのリポジトリローカル配置を追加した。
- USBシリアルを表示・公開せず一台へ固定する検出と`.env`処理を追加した。
- 型番/FQBN/SoC/Flash容量を一組で選ぶ対応表を追加した。
- ACL、全Flashバックアップ、SHA-256検証、復旧、書込みの安全ゲートを追加した。
- StackChanでは工場版置換に追加の明示フラグを要求した。
- 公式量産ソースの取得、依存検証、ホストテスト、日本語ESP-IDFビルドを追加した。

### 検証と公開

- `bash -n`、ShellCheck 0.11.0、shfmt 3.13.1、設定表検査、秘密情報監査を通過した。
- 模擬sysfsを使う検出・`.env`単体テストと、危険操作が許可フラグなしでは停止する安全ゲートテストを通過した。
- Arduino CLI 1.5.1、esptool 5.3.1を固定環境から使用できることを確認した。
- CoreS3向け確認スケッチをビルドし、Flash使用量501,431 bytes（15%）で完了した。
- AtomS3、CoreS3、Cardputer、NanoC6、Tab5の代表5構成でArduinoビルドを完了した。
- StackChan量産ソースの外部依存9 checkoutを固定commitと照合した。
- 公式モーション計算host testは1/1成功した。
- ESP-IDF v5.5.4で日本語設定を生成し、公式StackChan 1.4.3をESP32-S3向けにフルビルドした。
- `stack-chan.bin`は`0x39e1e0` bytes、最小app partitionの空きは`0x151e20` bytes（27%）だった。
- 上流ソース由来の警告は記録したが、ビルドエラーはなかった。
- 公開対象に`.env`、`.local/`、生USBシリアル、Flashイメージ、認証情報を含めていない。
- 公開先は`https://github.com/hjosugi/m5stack`とし、PR・commit・CI結果はGitHubの履歴を正本とする。

2026-07-31の検証中は、ポートACLの付与、シリアルopen、DTR/RTS、実機リセット、Flash読出し・書込みを行っていない。翌日の実機操作は上の2026-08-01記録へ分離した。
