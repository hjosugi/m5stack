// Copyright (c) Shinya Ishikawa. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full
// license information.
//
// StackChan DeepSeek音声版むけの自前パッチ。純正より吹き出しを小さく・幅を狭く
// し、長い文は電光掲示板のように横スクロール(マーキー)させる。
// build.sh がビルド前にライブラリへ上書きする。
// 変更点: TEXT_SIZE 2->1、楕円を小さく＆幅上限つき、長文はスクロール表示。

#ifndef BALLOON_H_
#define BALLOON_H_
#define LGFX_USE_V1
#include <M5Unified.h>
#include "DrawContext.h"
#include "Drawable.h"

#ifndef ARDUINO
#include <string>
typedef std::string String;
#endif  // ARDUINO

const int16_t TEXT_HEIGHT = 8;
const int16_t TEXT_SIZE = 1;    // 純正は2。半分にして文字を小さく。
const int16_t MIN_WIDTH = 24;   // 短文でも潰れない最小幅
const int16_t MAX_RX = 78;      // 吹き出し横半径の上限（画面からはみ出さない）
const int SCROLL_PXPS = 38;     // スクロール速度[px/秒]（電光掲示板。ゆっくり読める速さ）
const int cx = 232;             // 右下寄り（顔中央を避ける）
const int cy = 214;

namespace m5avatar {
class Balloon final : public Drawable {
 public:
  // constructor
  Balloon() = default;
  ~Balloon() = default;
  Balloon(const Balloon &other) = default;
  Balloon &operator=(const Balloon &other) = default;
  void draw(M5Canvas *spi, BoundingRect rect,
            DrawContext *drawContext) override {
    String text = drawContext->getspeechText();
    const lgfx::IFont *font = drawContext->getSpeechFont();
    if (text.length() == 0) {
      return;
    }
    ColorPalette *cp = drawContext->getColorPalette();
    uint16_t primaryColor = cp->get(COLOR_BALLOON_FOREGROUND);
    uint16_t backgroundColor = cp->get(COLOR_BALLOON_BACKGROUND);
    spi->setTextSize(TEXT_SIZE);
    spi->setTextColor(primaryColor, backgroundColor);
    M5.Lcd.setTextSize(TEXT_SIZE);
    M5.Lcd.setFont(font);
    int textWidth = M5.Lcd.textWidth(text.c_str());
    if (textWidth < MIN_WIDTH) textWidth = MIN_WIDTH;

    // 吹き出しの大きさ。幅は上限つき（長文でも固定窓にしてスクロールさせる）。
    int drawW = textWidth < (MAX_RX * 2) ? textWidth : (MAX_RX * 2);
    int rx = static_cast<int>(drawW * 0.6f) + 5;
    if (rx > MAX_RX) rx = MAX_RX;
    int textHeight = TEXT_HEIGHT * TEXT_SIZE;
    int ry = static_cast<int>(textHeight * 1.5f) + 2;

    // 枠→背景の順で塗り、小さなしっぽを口元へ向ける。
    spi->fillEllipse(cx, cy, rx + 2, ry + 2, primaryColor);
    spi->fillTriangle(cx - rx - 12, cy - ry - 14, cx - rx + 6, cy - 4,
                      cx - rx + 20, cy - 2, primaryColor);
    spi->fillEllipse(cx, cy, rx, ry, backgroundColor);
    spi->fillTriangle(cx - rx - 8, cy - ry - 10, cx - rx + 8, cy - 6,
                      cx - rx + 18, cy - 4, backgroundColor);

    // 文字を出せる内側の窓。
    int innerW = rx * 2 - 10;
    int clipX = cx - rx + 5;
    int clipY = cy - ry + 1;
    int clipH = ry * 2 - 2;
    spi->setClipRect(clipX, clipY, innerW, clipH);
    if (textWidth <= innerW) {
      // 収まる: 中央固定。
      spi->setTextDatum(MC_DATUM);
      spi->drawString(text.c_str(), cx, cy, font);
    } else {
      // はみ出す: 電光掲示板のように右→左へ流す。
      int period = textWidth + innerW;  // 流れ切ってから再登場するまで
      int off = static_cast<int>((millis() / (1000 / SCROLL_PXPS)) % period);
      int x = clipX + innerW - off;  // 右端から入ってくる
      spi->setTextDatum(ML_DATUM);
      spi->drawString(text.c_str(), x, cy, font);
    }
    spi->clearClipRect();
  }
};

}  // namespace m5avatar

#endif  // BALLOON_H_
