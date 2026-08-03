#include <M5Unified.h>

void setup() {
  auto config = M5.config();
  M5.begin(config);

  Serial.begin(115200);
  Serial.println("m5stack-safe-bootstrap");
  Serial.printf("chip=%s flash=%lu psram=%lu\n", ESP.getChipModel(),
                static_cast<unsigned long>(ESP.getFlashChipSize()),
                static_cast<unsigned long>(ESP.getPsramSize()));

  if (M5.Display.width() > 0) {
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(TFT_GREEN, TFT_BLACK);
    M5.Display.println("M5Stack ready");
    M5.Display.setTextSize(1);
    M5.Display.printf("%s\n", ESP.getChipModel());
  }
}

void loop() {
  M5.update();
  delay(20);
}
