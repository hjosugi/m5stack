# PC Screen Link relay

最短の設定順と端末側の手順は、[my-m5docsのPC画面リンク手順](https://hjosugi.github.io/m5stack/screen-link/)にまとめています。

PCブラウザーの`getDisplayMedia`で、利用者が明示的に選んだ画面またはウィンドウだけを取得します。ブラウザー内でCardputer用240×135とStackChan用320×240へ縮小・JPEG化し、認証付きWebSocketで端末へ中継します。音声は取得も送信もしません。

この方式はOS固有のスクリーンショットAPIを使わないため、GNOME/Waylandでもブラウザーの標準画面共有ダイアログを利用できます。

## 起動

推測されにくいtokenを作り、`.env`へ保存します。

```bash
cp pc/screen-link/.env.example pc/screen-link/.env
openssl rand -hex 24
task host:screen-link:setup
task host:screen-link:run
```

生成したtokenは画面へ貼らず、PC、Cardputer、StackChanの各`.env`に同じ値を設定します。relay起動後、PC自身のブラウザーで次を開きます。

```text
http://127.0.0.1:8765/
```

接続tokenを入力し、送信先、FPS、JPEG品質を選んで「画面共有を開始」を押します。ブラウザーの選択ダイアログで共有範囲を確認してください。

## セキュリティ

- relayは既定でLANから到達可能な`0.0.0.0:8765`へbindします。信頼できるLANだけで使ってください。
- producerと端末のWebSocketは共通tokenが一致しない接続を拒否します。ブラウザーは接続後の最初のWebSocket messageでtokenを送り、URLやaccess logへ残しません。
- フレームはディスクへ保存しません。2端末向けJPEGは並列生成し、ネットワークが詰まった場合は古いフレームを捨てて遅延の蓄積を防ぎます。
- インターネットへport-forwardしないでください。TLS終端を追加していないため、公衆LANでは使用しません。
- `/healthz`は接続台数だけを返し、画面やtokenを返しません。

relayを起動したterminalとは別のterminalで、host PCから接続状態を確認できます。別hostのrelayを確認する場合は`URL=http://host:port`を追加します。

```bash
task host:screen-link:status
task host:stackchan:status
```

## プロトコル

- producer: 先頭1 byteが送信先（1=Cardputer、2=StackChan）、残りがJPEG。
- Cardputer: JPEGをそのまま送信。
- StackChan: 公式実装に合わせて`type(1) + length(4, big endian) + payload`で送信し、video-modeとheartbeatも管理。

Python依存は[`uv.lock`](uv.lock)で固定します。テストは次で実行できます。

```bash
uv run --project pc/screen-link --frozen python -m unittest discover -s pc/screen-link/tests -v
```
