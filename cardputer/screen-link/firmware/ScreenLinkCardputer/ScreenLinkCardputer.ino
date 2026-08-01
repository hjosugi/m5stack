#include <ArduinoWebsockets.h>
#include <M5Cardputer.h>
#include <WiFi.h>

#if __has_include("screen_link_secrets.h")
#include "screen_link_secrets.h"
#else
#include "screen_link_secrets.example.h"
#define SCREEN_LINK_EXAMPLE_CONFIG 1
#endif

using namespace websockets;

namespace {
WebsocketsClient client;
bool connected = false;
bool speakerMuted = true;
uint32_t nextConnectAttempt = 0;

void drawCentered(const char* title, const char* detail)
{
  M5Cardputer.Display.fillScreen(TFT_BLACK);
  M5Cardputer.Display.setTextDatum(middle_center);
  M5Cardputer.Display.setTextColor(TFT_WHITE, TFT_BLACK);
  M5Cardputer.Display.setTextSize(1);
  M5Cardputer.Display.drawString(title, M5Cardputer.Display.width() / 2, 48);
  M5Cardputer.Display.setTextColor(TFT_LIGHTGREY, TFT_BLACK);
  M5Cardputer.Display.drawString(detail, M5Cardputer.Display.width() / 2, 74);
  M5Cardputer.Display.setTextDatum(top_left);
}

void drawMuteBadge()
{
  const char* label = SCREEN_LINK_ENABLE_SPEAKER ? (speakerMuted ? "MUTE" : "SPK") : "SPK OFF";
  const int width = SCREEN_LINK_ENABLE_SPEAKER ? 38 : 52;
  M5Cardputer.Display.fillRect(M5Cardputer.Display.width() - width, 0, width, 14, TFT_BLACK);
  M5Cardputer.Display.setTextColor(speakerMuted ? TFT_ORANGE : TFT_GREEN, TFT_BLACK);
  M5Cardputer.Display.setTextSize(1);
  M5Cardputer.Display.setCursor(M5Cardputer.Display.width() - width + 3, 3);
  M5Cardputer.Display.print(label);
}

void applyMute(bool muted)
{
  speakerMuted = muted;
  if (SCREEN_LINK_ENABLE_SPEAKER) {
    M5Cardputer.Speaker.stop();
    M5Cardputer.Speaker.setVolume(muted ? 0 : 64);
  }
  drawMuteBadge();
}

void onMessage(WebsocketsMessage message)
{
  if (!message.isBinary() || message.length() < 4) {
    return;
  }
  M5Cardputer.Display.drawJpg(reinterpret_cast<const uint8_t*>(message.c_str()), message.length(), 0, 0);
  drawMuteBadge();
}

void onEvent(WebsocketsEvent event, String)
{
  if (event == WebsocketsEvent::ConnectionOpened) {
    connected = true;
    drawCentered("SCREEN LINK", "Connected - waiting for PC");
    drawMuteBadge();
  } else if (event == WebsocketsEvent::ConnectionClosed) {
    connected = false;
    nextConnectAttempt = millis() + 2000;
  }
}

bool configurationIsUsable()
{
#ifdef SCREEN_LINK_EXAMPLE_CONFIG
  return false;
#else
  return strlen(SCREEN_LINK_WIFI_SSID) > 0 && strlen(SCREEN_LINK_TOKEN) >= 12;
#endif
}

void connectWiFi()
{
  drawCentered("SCREEN LINK", "Connecting Wi-Fi...");
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(SCREEN_LINK_WIFI_SSID, SCREEN_LINK_WIFI_PASSWORD);
  const uint32_t deadline = millis() + 20000;
  while (WiFi.status() != WL_CONNECTED && static_cast<int32_t>(deadline - millis()) > 0) {
    delay(100);
  }
}

void connectRelay()
{
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) {
      drawCentered("WI-FI ERROR", "Retrying...");
      nextConnectAttempt = millis() + 3000;
      return;
    }
  }

  client.close();
  client = WebsocketsClient();
  client.addHeader("Authorization", SCREEN_LINK_TOKEN);
  client.onMessage(onMessage);
  client.onEvent(onEvent);
  drawCentered("SCREEN LINK", "Connecting PC relay...");
  if (!client.connect(SCREEN_LINK_SERVER_HOST, SCREEN_LINK_SERVER_PORT, "/ws/cardputer")) {
    connected = false;
    nextConnectAttempt = millis() + 3000;
    drawCentered("RELAY ERROR", "Check PC address/token");
  }
}
}  // namespace

void setup()
{
  auto config = M5.config();
  // 画面リンクは音声を扱わない。既定ではI2S speaker自体を初期化しない。
  config.internal_spk = SCREEN_LINK_ENABLE_SPEAKER != 0;
  M5Cardputer.begin(config);
  M5Cardputer.Display.setRotation(1);
  M5Cardputer.Display.setFont(&fonts::Font2);

  // speakerを有効にしたビルドでも、起動時は必ずmuteから始める。
  applyMute(true);

  if (!configurationIsUsable()) {
    drawCentered("CONFIG REQUIRED", "Run cardputer/screen-link/build.sh");
    drawMuteBadge();
    return;
  }
  connectRelay();
}

void loop()
{
  M5Cardputer.update();

  if (SCREEN_LINK_ENABLE_SPEAKER && M5Cardputer.Keyboard.isChange() && M5Cardputer.Keyboard.isKeyPressed('m')) {
    applyMute(!speakerMuted);
  }

  if (!configurationIsUsable()) {
    delay(20);
    return;
  }

  if (connected) {
    client.poll();
  } else if (static_cast<int32_t>(millis() - nextConnectAttempt) >= 0) {
    connectRelay();
  }
  delay(1);
}
