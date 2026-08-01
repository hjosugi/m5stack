# PC画面をCardputer／StackChanへ送る

## できること

PCのブラウザーで明示的に選んだ画面またはウィンドウを、同じLAN上のCardputer AdvまたはStackChanへJPEG列として送ります。音声、マイク、カメラ映像は取得も送信もしません。

| 構成 | 役割 | 解像度 |
| --- | --- | --- |
| PC relay | 画面選択、縮小、JPEG化、認証付き中継 | 送信先に合わせる |
| Cardputer Adv client | JPEGを画面へ表示 | 240×135 |
| StackChan client | 公式AVATAR WebSocket経路で表示 | 320×240 |

ブラウザー標準の`getDisplayMedia`を使うため、GNOME／Waylandでもブラウザーの画面共有ダイアログから共有範囲を選べます。

## 1. PC relayを設定する

推測されにくいtokenを作り、追跡対象外の`.env`へ保存します。

```bash
cp pc/screen-link/.env.example pc/screen-link/.env
openssl rand -hex 24
task host:screen-link:setup
task host:screen-link:run
```

生成したtokenは公開画面へ貼らず、PC、Cardputer、StackChanの各`.env`へ同じ値を設定します。relay起動後、PC自身のブラウザーで次を開きます。

```text
http://127.0.0.1:8765/
```

接続token、送信先、FPS、JPEG品質を選び、「画面共有を開始」を押します。ブラウザーが表示する選択ダイアログで、共有対象を毎回確認してください。

## 2. Cardputer Advを準備する

```bash
cp cardputer/screen-link/.env.example cardputer/screen-link/.env
task cardputer:screen-link:build
```

`.env`へ2.4 GHz Wi-Fi、PCのLAN IP、relayと同じtokenを設定します。成果物は`.local/build/cardputer-screen-link/`へ作られ、このtaskだけでは実機へ書き込みません。

Cardputer clientはspeakerを初期化しない設定が既定です。詳細は[Cardputerをミュートする](cardputer-mute.md)を参照してください。

## 3. StackChanを準備する

```bash
cp stackchan/screen-link/.env.example stackchan/screen-link/.env
task stackchan:screen-link:build
```

固定した公式StackChan 1.4.3系のAVATAR WebSocket表示経路を使います。`stack-chan/stack-chan`コミュニティ版v1.0.0には同じ受信経路がないため、そのままでは利用できません。

生成物は`.local/build/stackchan-screen-link-ja/`へ作られ、このtaskだけでは実機へ書き込みません。ファームウェアを切り替える前に、[安全な実機手順](safe-workflow.md)と[復旧手順](recovery.md)を確認してください。

## 接続状態を確認する

relayを起動したterminalとは別のterminalで実行します。

```bash
task host:screen-link:status
task host:cardputer:status
task host:stackchan:status
```

別PC上のrelayを確認する場合だけ、信頼できるLAN内で`URL=http://host:port`を指定します。

## セキュリティと制約

- relayは既定でLANから到達可能な`0.0.0.0:8765`へbindします。信頼できるLANだけで使います。
- producerと端末は共通tokenが一致しない接続を拒否します。tokenはURLやaccess logへ含めません。
- フレームはディスクへ保存しません。送信が詰まった場合は古いフレームを捨てます。
- TLS終端はありません。インターネットへのport-forwardや公衆LANでの使用はしません。
- `/healthz`は接続台数だけを返し、画面やtokenを返しません。
- build、status taskはサーボ制御、リセット、Flash書込みを行いません。

## 詳細

- [PC relayの実装とプロトコル](https://github.com/hjosugi/m5stack/tree/main/pc/screen-link)
- [Cardputer Adv client](https://github.com/hjosugi/m5stack/tree/main/cardputer/screen-link)
- [StackChan client](https://github.com/hjosugi/m5stack/tree/main/stackchan/screen-link)
