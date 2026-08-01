# ESP32 GitHubプロジェクトの見方

GitHubの`esp32`トピックで調査した主要プロジェクトを、用途と導入判断が分かる形に整理した記録です。

- 調査日: 2026-07-30
- 元記録: [ESP32 GitHubプロジェクトまとめ（Gist）](https://gist.github.com/hjosugi/fd7b6c5d0c9728c0b157030cf28e315a)
- 注意: GitHubトピックの登録、掲載順、件数、更新時刻は変化します。ここでは調査時点のスナップショットとして扱います。

## 分野別一覧

| 分野 | プロジェクト | 主な用途 | このリポジトリでの扱い |
| --- | --- | --- | --- |
| AI・音声端末 | [78/xiaozhi-esp32](https://github.com/78/xiaozhi-esp32) | ESP32音声AI・MCP対応端末 | StackChan公式ファームウェアの上流依存として固定検証 |
| AIバックエンド | [xinnan-tech/xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server) | Xiaozhi端末向け会話・AI連携server | 外部server候補。秘密情報と公開範囲を分離して評価 |
| Wi-Fiセンシング | [ruvnet/RuView](https://github.com/ruvnet/RuView) | Wi-Fi信号を使う空間センシング | 対応chip、CSI取得、配置、modelを個別確認する必要あり |
| スマートホーム | [esphome/esphome](https://github.com/esphome/esphome) | YAML中心のHome Assistant連携 | センサー・家電連携の第一候補 |
| 汎用IoT | [arendst/Tasmota](https://github.com/arendst/Tasmota) | MQTT、HTTP、OTA、rule対応firmware | 対応boardを先に確認 |
| LED制御 | [wled/WLED](https://github.com/wled/WLED) | Digital RGB LED制御 | LED作品を短時間で試す候補 |
| 組み込みGUI | [lvgl/lvgl](https://github.com/lvgl/lvgl) | LCD、OLED、touch UI | 高機能UI向け。M5GFXとの役割を区別する |
| Arduino開発 | [espressif/arduino-esp32](https://github.com/espressif/arduino-esp32) | Espressif公式Arduino Core | このrepoのArduino経路の基盤 |
| 開発環境 | [platformio/platformio-core](https://github.com/platformio/platformio-core) | 依存、build、upload、debug、test | 本repoはNixとGo Taskを正本にするため未採用 |
| JSON処理 | [bblanchon/ArduinoJson](https://github.com/bblanchon/ArduinoJson) | 組み込みC++向けJSON library | firmwareの依存として必要時に採用 |
| Go開発 | [tinygo-org/tinygo](https://github.com/tinygo-org/tinygo) | Goによるmicrocontroller開発 | 対応chip・board・libraryを先に確認 |
| Lua開発 | [nodemcu/nodemcu-firmware](https://github.com/nodemcu/nodemcu-firmware) | LuaでESP8266／ESP32を操作 | Arduino／ESP-IDFとは別経路 |
| Game・graphics | [raysan5/raylib](https://github.com/raysan5/raylib) | 軽量game・graphics library | ESP32上で直接使える条件を個別確認 |
| LoRa通信 | [meshtastic/firmware](https://github.com/meshtastic/firmware) | off-grid mesh通信 | Cardputer内蔵機能ではなく対応radioが必要 |
| 3D printer | [MarlinFirmware/Marlin](https://github.com/MarlinFirmware/Marlin) | 3D printer制御firmware | M5Stack向けappではない |
| Robot | [makerspet/oomwoo](https://github.com/makerspet/oomwoo) | ESP32、LiDAR、ROS 2を使うrobot | 複数systemの統合作例 |
| 電子paper | [lmarzen/esp32-weather-epd](https://github.com/lmarzen/esp32-weather-epd) | 低消費電力の天気表示 | 対応displayとAPI条件を確認 |
| Telemetry | [Serial-Studio/Serial-Studio](https://github.com/Serial-Studio/Serial-Studio) | UART、BLE、MQTT等の可視化 | PC側の観測tool候補 |
| Security検証 | [justcallmekoko/ESP32Marauder](https://github.com/justcallmekoko/ESP32Marauder) | Wi-Fi・Bluetoothの診断 | 所有・許可済み環境だけ。初心者の導入候補から除外 |

通信妨害を目的とするプロジェクトは、通常の学習・制作候補として掲載しません。第三者の通信へ影響する送信や、所有・管理していないnetworkへの検証は行わないでください。

## 目的から選ぶ

| やりたいこと | 第一候補 | 先に確認すること |
| --- | --- | --- |
| 音声AI端末 | Xiaozhi ESP32 | server運用、API、録音データ、秘密情報の扱い |
| StackChan風端末 | ESP32-S3 + LVGL + Xiaozhi | 対応board、servo安全域、音声codec、電源 |
| Smart home | ESPHome | 対応sensor、Home Assistant、local control範囲 |
| LED作品 | WLED | 電源容量、LED本数、level、発熱 |
| LoRa mesh | Meshtastic | 対応radio、周波数帯、地域の法令 |
| Sensor可視化 | Serial Studio | protocol、sampling rate、PC接続方法 |
| C/C++開発 | Arduino ESP32 | board packageとlibraryの対応version |
| Go開発 | TinyGo | ESP32 variant、周辺機器driver、debug手段 |
| 小型表示端末 | LVGLまたはM5GFX | display driver、memory、refresh rate |

## 導入前チェック

1. READMEだけでなく、license、release、未解決Issue、最終commitを確認する。
2. `ESP32対応`を製品対応と読み替えず、chip、board revision、pin、display、audio codecを照合する。
3. 完成済みbinaryは配布元とSHA-256を確認し、工場版へ戻す経路を先に用意する。
4. network、microphone、camera、認証情報を扱う場合は、送信先と保存範囲を確認する。
5. 本repoへ採用する依存はversionまたはcommitを固定し、buildと実機動作を別々に検証する。

Cardputerに限定したsoftware一覧は[Cardputerコミュニティソフトの見方](cardputer-community-software.md)、製品・library・toolの基礎は[M5Stackとマイコンの全体像](m5stack-beginner.md)を参照してください。
