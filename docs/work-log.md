# 作業記録

## 2026-07-31

### 対象確定

- ユーザー指定の公式`m5stack/StackChan`を主対象とした。
- 公式仕様でCoreS3、ESP32-S3、16 MB Flash、8 MB PSRAM、ロボット本体USB-Cのデータ接続を確認した。
- sysfsでUSB 2.0 Hub `214b:7250`配下のEspressif native USB `303a:1001`と`cdc_acm`を確認した。
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

検証中もポートACLの付与、シリアルopen、DTR/RTS、実機リセット、Flash読出し・書込みは行っていない。
