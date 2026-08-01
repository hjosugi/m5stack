# StackChan PC画面リンク

PC側を含む設定順は、[GitHub PagesのPC画面リンク手順](https://hjosugi.github.io/m5stack/screen-link.html)にまとめています。

PCブラウザーで選んだ画面またはウィンドウを320×240 JPEGへ変換し、公式M5Stack StackChanファームウェアの`AVATAR`アプリへ送ります。

## 対応ファームウェア

この方式は公式[`m5stack/StackChan`](https://github.com/m5stack/StackChan) 1.4.3に実装されているWebSocket JPEG表示経路を使います。`stack-chan/stack-chan`コミュニティ版v1.0.0には同じ受信経路がないため、そのままでは利用できません。

現在コミュニティ版を使っている実機へ、この画面リンク版を自動で書き込むことはありません。切り替える場合は、先にM5Burner等の復旧経路を確認してください。

## 設定とビルド

PC relayを動かすPCのLAN IPと、relayと同じtokenを設定します。

```bash
cp stackchan/screen-link/.env.example stackchan/screen-link/.env
<<<<<<< HEAD
./stackchan/screen-link/build.sh
||||||| 25f29cd
=======
task stackchan:screen-link:build
>>>>>>> agent/go-task-migration
```

tokenとPC固有IPを含む`.env`、生成sdkconfig、ファームウェアは`.local/`内に置かれ、Git管理されません。固定した公式ソース、依存、host testsを検証してから`.local/build/stackchan-screen-link-ja/`へビルドします。このコマンドは実機へ書き込みません。

## 使い方

1. PCとStackChanを同じ2.4 GHz LANへ接続する。
2. PC relayを起動し、ブラウザーで画面共有を開始する。
3. StackChanで`AVATAR`アプリを開く。
4. 接続後、PCから受け取ったJPEGが全画面表示される。

relayは公式プロトコルに合わせて、JPEGを`type + big-endian length + payload`で包み、video-modeとheartbeatも送信します。音声・マイク・カメラ映像はPC画面リンクでは送信しません。
