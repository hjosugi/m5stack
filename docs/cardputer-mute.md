# Cardputer-Advをミュートする

## いまBruceの音を止める

画面に`Bruce`と表示されている場合、`Q`は効きません。次の順に操作します。

1. `` ` ``または`Backspace`でBruceのメインメニューまで戻る。
2. `;`または`,`で上、`.`または`/`で下へ移動する。
3. `Config`を選び、`Enter`を押す。
4. `Audio Config`を選び、`Enter`を押す。
5. `Sound: ON`を選んで`Enter`を押し、表示が`Sound: OFF`になったことを確認する。

Bruce 1.16はこの操作で`soundEnabled`を反転し、設定fileへ保存します。すでに音声fileを再生中なら再生を止め、設定後にBruceを再起動して確認してください。

`Audio Config`がない場合は、`About`で版を確認します。本ページで確認した公式配布物は`Bruce-m5stack-cardputer.bin` 1.16です。別build、Lite build、古い版ではメニューが異なる可能性があります。

## M5LauncherからBruceを起動している場合

M5Launcherは複数firmwareのinstall・起動・partition管理を行う基盤であり、起動したBruceのマスターミュートではありません。M5Launcherへ戻って`Q`を押すのではなく、Bruceを起動して上記の`Audio Config`を変更します。

2026-08-01時点の現行M5Launcherは[2.8.0](https://github.com/bmorcelli/Launcher/releases/tag/2.8.0)です。Cardputer用sourceと設定項目には、起動先firmwareの音声を一括停止する設定はありません。

## 公式UserDemoの場合

M5Stack公式のCardputer-Adv UserDemoだけは、画面を見ながら前面キーボードの`Q`を押すと静音モードを切り替えられます。画面はタッチパネルではありません。

| 画面 | 操作 | 結果 |
| --- | --- | --- |
| 起動ロゴ | `Q` | 静音モードを有効にしてランチャーへ進む。起動画面では解除できない |
| メインのアプリ選択画面 | `Q` | 静音モードをON／OFFする |
| 画面上部 | 消音アイコンを確認 | アイコン表示中は静音モード |
| 再起動後 | 操作不要 | 設定はNVSから復元される |

## 画面別の結論

| いま表示されているfirmware | 消音操作 |
| --- | --- |
| Bruce 1.16 | `Config` → `Audio Config` → `Sound: OFF` |
| M5Launcher 2.8.0 | 起動先firmwareを開き、そのfirmware内で設定する |
| 公式UserDemo CardputerADV | launcher画面で`Q` |
| Picoware、UIFlow2、game等 | 各firmware固有。`Q`やBruce設定は引き継がれない |

Cardputer-Advには全firmwareへ共通する物理mute switchはありません。firmwareを切り替えるたびに、そのfirmwareの設定を確認します。

## 何が静かになるか

公式ADV UserDemoの静音モードが抑止するのは、ランチャーの起動音、ランダム効果音、キー入力音です。

`Record`アプリの録音再生は静音フラグを参照せず、スピーカー音量を直接設定して再生します。従って`Q`は全アプリを強制的に無音にするマスターミュートではありません。録音再生を始める前にも音が出てよいか確認してください。

Cardputerにはスピーカーとマイクの両方があります。`Q`で止まるのは上記のスピーカー効果音であり、マイク機能を停止する操作ではありません。

## 根拠と、以前の説明が違った理由

2026-08-01に公式[`M5Cardputer-UserDemo`](https://github.com/m5stack/M5Cardputer-UserDemo)をブランチ別に再確認しました。

- `CardputerADV`ブランチのコミット`b549eac0a3c65bc108186c276b8fac0a214aaa4e`には、[`Q`で静音を切り替えるランチャー処理](https://github.com/m5stack/M5Cardputer-UserDemo/blob/b549eac0a3c65bc108186c276b8fac0a214aaa4e/main/apps/app_launcher/view/menu/menu.cpp#L83-L88)があります。
- [起動処理](https://github.com/m5stack/M5Cardputer-UserDemo/blob/b549eac0a3c65bc108186c276b8fac0a214aaa4e/main/apps/app_launcher/view/boot_anim/boot_anim.cpp#L49-L71)は保存済みの`quiet_mode`を音の再生前にNVSから復元します。
- [システムバー](https://github.com/m5stack/M5Cardputer-UserDemo/blob/b549eac0a3c65bc108186c276b8fac0a214aaa4e/main/apps/app_launcher/view/system_bar/system_bar.cpp#L106-L109)は静音中に専用アイコンを描画します。
- 通常の`main`ブランチは初代Cardputer系の実装であり、同じ静音処理がありません。

最初の調査では通常の`main`だけを確認してADV版にも設定がないと判断していました。これは対象ブランチの取り違えでした。本ページはADV専用ブランチの実装を正本として訂正しています。

## Bruce 1.16の場合

Bruceでは`Config`の`Audio Config`から`Sound: OFF`へ切り替えます。音量は`Sound Volume`で10〜100%を選べます。公式UserDemoの`Q`操作とは共通ではありません。対応状況、外付け無線モジュール、導入上の注意は[Bruce 1.16調査](bruce-cardputer-adv.md)、採用構成は[Cardputer-Adv firmware構成](cardputer-firmware-guide.md)にまとめています。

## 自作ファームウェアで完全に消音する

M5Stack公式のSpeaker APIでは音量を0〜255で設定できます。

```cpp
M5Cardputer.Speaker.stop();
M5Cardputer.Speaker.setVolume(0);
```

画面設定として実装する場合は、音を出す全経路が同じ状態を参照するようにします。

1. `Sound: On / Muted`を描画する。
2. キーボードで選択し、`Enter`で切り替える。
3. ミュート前の音量を保存し、解除時に戻す。
4. 再起動後も維持する場合だけNVSへ保存する。
5. 各アプリが再生直前に固定音量を設定し直さないようにする。

マイクも止める場合は、スピーカーとは別に録音処理を終了します。

```cpp
M5Cardputer.Mic.end();
```

## 3.5 mm端子

Cardputer-Advは3.5 mm端子へヘッドホン等を接続すると、内蔵スピーカーアンプが無効になります。これは出力先の切替であり、音声信号自体のミュートではありません。

## 参照した公式情報

- [Cardputer-Adv製品文書](https://docs.m5stack.com/en/core/Cardputer-Adv): ES8311、NS4150B、3.5 mm端子、電源、充電
- [Cardputer / Cardputer-Adv Speaker](https://docs.m5stack.com/en/arduino/m5cardputer/speaker): Speaker APIと音量範囲
- [Cardputer Mic](https://docs.m5stack.com/en/arduino/m5cardputer/mic): マイクとスピーカーの切替例
- [M5Cardputer-UserDemo `CardputerADV`](https://github.com/m5stack/M5Cardputer-UserDemo/tree/CardputerADV): ADV用ランチャーと静音処理
- [Bruce 1.16 `Audio Config`](https://github.com/BruceDevices/firmware/blob/59e83bfbd8a63a6b67ea23498e15c710a1ed9657/src/core/menu_items/ConfigMenu.cpp#L124-L149): `Sound`切替と保存
- [M5Launcher 2.8.0](https://github.com/bmorcelli/Launcher/tree/2.8.0): launcherと起動先firmwareの設定分離

確認対象は上記コミットです。別のファームウェアや将来版で画面が異なる場合は、ファームウェア名と版を先に確認してください。
