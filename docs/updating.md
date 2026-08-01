# 依存関係の更新手順

更新は「最新版へ動かす」だけでなく、出典、実体commit、ビルド、実機保全を一組で確認します。

## Arduino

1. [M5Stack公式Board Manager索引](https://static-cdn.m5stack.com/resource/arduino/package_m5stack_index.json)を取得し、最新版とarchive checksumを確認する。
2. Arduino Library Manager索引でM5Unified、M5GFX、M5Cardputer、依存ライブラリを確認する。
3. StackChan-BSPの`library.properties`とcommitを確認する。
4. `versions.env`を更新する。
5. 新しい空の`.local/`相当で`task arduino:setup`を行う。
6. `task arduino:matrix`と`task check`を実行する。

M5Stack公式CoreとEspressif汎用Coreの版が違う場合、M5Stack固有FQBNを使う本リポジトリでは公式M5Stack索引を優先します。

## StackChan量産ソース

1. [公式StackChanリポジトリ](https://github.com/m5stack/StackChan)のHEAD、`firmware/CMakeLists.txt`の版、`firmware/README.md`のESP-IDF指定を確認する。
2. `repos.json`にある全URL/refを確認し、各refを40桁commitへ解決する。
3. ESP-IDFの注釈付きtagはtag objectではなく、checkout後のcommitを記録する。
4. `versions.env`と`config/upstream.lock`を同じ変更で更新する。
5. 新しい`.local/upstream`で`task stackchan:factory:setup`を行う。
6. `task stackchan:factory:build`で依存照合、host tests、日本語設定、ESP32-S3ビルドを確認する。
7. 上流のライセンス、partition、OTA、Secure Boot/Flash Encryption設定の変更を読む。

公開ソースの更新は、工場配布版より新しいことを意味しません。更新後も自動Flashは追加せず、実機の全Flashバックアップと物理安全を別途確認します。

## 公開前

```bash
task check
git diff --check
git status --short
```

`.env`、`.local/`、Flashイメージ、生USBシリアル、Wi-Fi/API認証情報が追跡対象にないことを確認します。固定commitは40桁の実体SHAを使い、検証なしに移動するbranch名だけを記録しません。
