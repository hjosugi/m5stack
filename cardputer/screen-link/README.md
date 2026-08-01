# Cardputer Adv PC画面リンク

PC側を含む設定順は、[GitHub PagesのPC画面リンク手順](https://hjosugi.github.io/m5stack/screen-link.html)にまとめています。

PCブラウザーで選んだ画面またはウィンドウを、Wi-Fi経由のJPEG列としてCardputer Adv（240×135）へ表示します。音声は送信しません。

## 音をmuteする

このclientは`CARDPUTER_SPEAKER_ENABLED=0`を既定値とし、`M5.config()`の`internal_spk`を無効にしてspeaker自体を初期化しません。画面リンクだけならこの設定が最も確実です。

既存のM5Cardputerスケッチを実行時にmuteする場合は次の2行を使用します。

```cpp
M5Cardputer.Speaker.stop();
M5Cardputer.Speaker.setVolume(0);
```

`CARDPUTER_SPEAKER_ENABLED=1`でビルドした場合も起動時はmuteです。`M`キーで音量0と64を切り替えられます。

## 設定とビルド

```bash
cp cardputer/screen-link/.env.example cardputer/screen-link/.env
```

`.env`へ2.4 GHz Wi-Fi、PCのLAN IP、PC relayと同じtokenを設定します。認証情報はGitへ追加しません。

```bash
<<<<<<< HEAD
./cardputer/screen-link/build.sh
||||||| 25f29cd
=======
task cardputer:screen-link:build
>>>>>>> agent/go-task-migration
```

成果物は`.local/build/cardputer-screen-link/`へ生成されます。このコマンドは実機へ書き込みません。既存ファームウェアを置換するため、書き込み前に現在のファームウェアの復旧経路を用意してください。

## 操作

- PC relayと同じ2.4 GHz LANへ接続します。
- 接続後はブラウザーから届いたJPEGだけを描画します。
- `SPK OFF`はspeaker未初期化、`MUTE`は実行時音量0を表します。
- 接続が切れた場合は3秒間隔で自動再接続します。
