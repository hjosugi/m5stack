# Cardputerをミュートする

## 結論

M5Stack公式のCardputer UserDemoには、画面からスピーカー音量を変更したりミュートしたりする設定メニューがありません。Cardputerの画面はタッチパネルではないため、設定画面があるファームウェアでも前面キーボードか上面のG0ボタンで操作します。

したがって、画面からミュートできるかどうかは現在書き込まれているファームウェア次第です。まず起動画面や「About」でファームウェア名と版を確認してください。

| 使用中のもの | 画面からのミュート |
| --- | --- |
| M5Stack公式Cardputer UserDemo | 設定メニューがないため不可 |
| Cardputer Advの3.5 mm AUX | 挿すと内蔵スピーカーからAUXへ出力が切り替わる。画面設定ではなく、無音も保証しない |
| M5Launcher、Bruce等の別ファームウェア | メニューと操作が版ごとに異なる。対象ファームウェアの文書を確認する |
| 自作ファームウェア | 画面項目と保存処理を実装できる |

## 「ミュート」の対象を分ける

Cardputerにはスピーカーとマイクの両方があります。スピーカーの消音とマイクの停止は別の操作です。

- スピーカーミュート: キー操作音、WAV、音声再生を出さない。
- マイクミュート: 録音処理を止める。スピーカー音量を0にしてもマイクは止まらない。

録音や音声通信を扱うファームウェアでは、画面に`Speaker: Muted`と`Mic: Off`を別々に表示するのが安全です。

## 公式UserDemoで設定できない根拠

2026-08-01にM5Stack公式[`M5Cardputer-UserDemo`](https://github.com/m5stack/M5Cardputer-UserDemo)のコミット`a34d7ebcd508fb903a2b1123be8c8b54abd55d07`を確認しました。

- ランチャーに音量設定アプリはありません。
- キー移動音はソース内の固定音量で再生されます。
- 音量を不揮発メモリーへ保存する設定処理はありません。

画面にスピーカーアイコンが見つからないのは操作の見落としではなく、公式デモがハードウェア機能の見本であり、一般的なOSの設定画面を備えていないためです。

## 自作ファームウェアへ画面設定を追加する

M5Stack公式のCardputer Speaker APIは、CardputerとCardputer Advの両方で`M5Unified`の`Speaker_Class`を使用します。論理的な消音は音量を0へ設定し、マイクを止める場合はマイク処理を終了します。

```cpp
// スピーカーを消音する
M5Cardputer.Speaker.stop();
M5Cardputer.Speaker.setVolume(0);

// マイクを停止する（スピーカーとは別設定）
M5Cardputer.Mic.end();
```

画面設定として実装する場合は、次の状態を持たせます。

1. `Sound: On / Muted`を描画する。
2. キーボードで選択し、Enterで切り替える。
3. ミュート前の音量を保存し、解除時に戻す。
4. 再起動後も維持する場合だけ、ESP32のNVSへ設定値を保存する。
5. 音を再生する全アプリが同じ設定を参照する。

`setVolume(0)`だけを一画面で呼び出しても、別アプリが固定音量を再設定すれば音は戻ります。ランチャーと各アプリへ共通の設定値を渡す必要があります。

## Cardputer AdvのAUXについて

Cardputer Advは3.5 mm端子へヘッドホンまたは外部スピーカーを接続すると、内蔵スピーカーからAUXへ出力が切り替わります。これは内蔵スピーカーを静かにする手段にはなりますが、音声信号自体のミュートではありません。

## 参照した公式情報

- [Cardputer / Cardputer Adv Speaker](https://docs.m5stack.com/en/arduino/m5cardputer/speaker): 対応機種、Speaker API、AUX出力切替
- [Cardputer Mic](https://docs.m5stack.com/en/arduino/m5cardputer/mic): マイクとスピーカーを切り替える公式例
- [Cardputer Adv製品文書](https://docs.m5stack.com/en/core/Cardputer-Adv): スピーカーアンプ、3.5 mm端子、操作部
- [M5Cardputer-UserDemo](https://github.com/m5stack/M5Cardputer-UserDemo): 公式デモのランチャー、キー音、Speaker実装

調査日以降に公式デモへ設定画面が追加される可能性があります。手元の画面がこの説明と違う場合は、ファームウェア名と版を確認してから、その版の操作方法を追記します。
