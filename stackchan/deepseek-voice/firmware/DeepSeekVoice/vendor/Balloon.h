// Copyright (c) Shinya Ishikawa. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full
// license information.
//
// StackChan DeepSeek音声版むけの自前パッチ。純正より吹き出しを小さく・幅を狭く
// して顔の邪魔をしないようにする。build.sh がビルド前にライブラリへ上書きする。
// 変更点: TEXT_SIZE 2->1（半分）、楕円を小さく＆横幅を狭く、位置を下寄せ。

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
const int16_t TEXT_SIZE = 1;   // 純正は2。半分にして文字を小さく。
const int16_t MIN_WIDTH = 24;  // 短文でも潰れない最小幅
const int cx = 232;            // 右下寄り（顔中央を避ける）
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
    M5.Lcd.setTextSize(TEXT_SIZE);
    M5.Lcd.setTextDatum(MC_DATUM);
    spi->setTextSize(TEXT_SIZE);
    spi->setTextColor(primaryColor, backgroundColor);
    spi->setTextDatum(MC_DATUM);
    M5.Lcd.setFont(font);
    int textWidth = M5.Lcd.textWidth(text.c_str());
    if (textWidth < MIN_WIDTH) textWidth = MIN_WIDTH;
    int textHeight = TEXT_HEIGHT * TEXT_SIZE;
    // 楕円半径。幅は少し狭め（textWidth*0.6）、高さも低め。
    int rx = static_cast<int>(textWidth * 0.6f) + 5;
    int ry = static_cast<int>(textHeight * 1.5f) + 2;
    // 枠→背景の順で塗り、小さなしっぽを口元へ向ける。
    spi->fillEllipse(cx, cy, rx + 2, ry + 2, primaryColor);
    spi->fillTriangle(cx - rx - 12, cy - ry - 14, cx - rx + 6, cy - 4,
                      cx - rx + 20, cy - 2, primaryColor);
    spi->fillEllipse(cx, cy, rx, ry, backgroundColor);
    spi->fillTriangle(cx - rx - 8, cy - ry - 10, cx - rx + 8, cy - 6,
                      cx - rx + 18, cy - 4, backgroundColor);
    spi->drawString(text.c_str(), cx, cy, font);  // MC_DATUM: 中心に描画
  }
};

}  // namespace m5avatar

#endif  // BALLOON_H_
