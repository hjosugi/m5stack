// CardputerToolkit — M5Cardputer用のオフライン簡易ツール集。
//
// 収録: Snake(ゲーム) / WiFiスキャナ / BLEスキャナ / Sysinfo。
// いずれもWi-FiのAP参加や鍵は不要。周辺電波は「受動的に観測するだけ」で、
// deauth・ビーコン偽装・ハンドシェイク奪取など妨害/攻撃系は意図的に含めない。
// 自分の機材や許可された環境での動作確認・電波調査(検証)用途を想定する。

#include <M5Cardputer.h>
#include <WiFi.h>
#include <BLEDevice.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

namespace {

// Cardputerに印字された矢印キー。;=上 .=下 ,=左 /=右。
constexpr char KEY_UP = ';';
constexpr char KEY_DOWN = '.';
constexpr char KEY_LEFT = ',';
constexpr char KEY_RIGHT = '/';
constexpr char KEY_ESC = '`';  // 一段戻る / 終了

enum class Screen { Menu, Wifi, Ble, Snake, Sysinfo };

Screen screen = Screen::Menu;
int menuIndex = 0;

const char* const kMenuItems[] = {
    "Snake  (game)",
    "WiFi Scanner",
    "BLE Scanner",
    "System Info",
};
constexpr int kMenuCount = sizeof(kMenuItems) / sizeof(kMenuItems[0]);

// ---- 入力 -------------------------------------------------------------
// キーボードのchange時に、押された代表キーを1文字返す。無ければ0。
// enter='\r' / del=0x08 / それ以外は最初のword文字。
char pollKey()
{
  if (!M5Cardputer.Keyboard.isChange() || !M5Cardputer.Keyboard.isPressed()) {
    return 0;
  }
  auto state = M5Cardputer.Keyboard.keysState();
  if (state.enter) {
    return '\r';
  }
  if (state.del) {
    return 0x08;
  }
  if (!state.word.empty()) {
    return state.word.front();
  }
  return 0;
}

// ---- 描画補助 ---------------------------------------------------------
auto& display()
{
  return M5Cardputer.Display;
}

void drawHeader(const char* title)
{
  display().fillScreen(TFT_BLACK);
  display().fillRect(0, 0, display().width(), 16, TFT_NAVY);
  display().setTextColor(TFT_WHITE, TFT_NAVY);
  display().setTextDatum(top_left);
  display().setCursor(4, 1);
  display().print(title);
  display().setTextColor(TFT_WHITE, TFT_BLACK);
}

void drawFooter(const char* hint)
{
  const int y = display().height() - 12;
  display().fillRect(0, y, display().width(), 12, TFT_DARKGREY);
  display().setTextColor(TFT_WHITE, TFT_DARKGREY);
  display().setCursor(4, y);
  display().print(hint);
  display().setTextColor(TFT_WHITE, TFT_BLACK);
}

// ---- メニュー ---------------------------------------------------------
void drawMenu()
{
  drawHeader("CardputerToolkit");
  for (int i = 0; i < kMenuCount; ++i) {
    const int y = 22 + i * 20;
    if (i == menuIndex) {
      display().fillRect(0, y - 2, display().width(), 18, TFT_DARKGREEN);
      display().setTextColor(TFT_WHITE, TFT_DARKGREEN);
    } else {
      display().setTextColor(TFT_LIGHTGREY, TFT_BLACK);
    }
    display().setCursor(10, y);
    display().print(kMenuItems[i]);
  }
  drawFooter(";/. move  enter select");
}

void enterScreen(Screen next);  // 前方宣言

void handleMenu(char key)
{
  if (key == KEY_UP) {
    menuIndex = (menuIndex + kMenuCount - 1) % kMenuCount;
    drawMenu();
  } else if (key == KEY_DOWN) {
    menuIndex = (menuIndex + 1) % kMenuCount;
    drawMenu();
  } else if (key == '\r') {
    switch (menuIndex) {
      case 0: enterScreen(Screen::Snake); break;
      case 1: enterScreen(Screen::Wifi); break;
      case 2: enterScreen(Screen::Ble); break;
      case 3: enterScreen(Screen::Sysinfo); break;
    }
  }
}

// ---- WiFiスキャナ (受動的なAP一覧の観測) ------------------------------
int wifiCount = 0;
int wifiTop = 0;

const char* authLabel(wifi_auth_mode_t mode)
{
  switch (mode) {
    case WIFI_AUTH_OPEN: return "OPEN";
    case WIFI_AUTH_WEP: return "WEP";
    case WIFI_AUTH_WPA_PSK: return "WPA";
    case WIFI_AUTH_WPA2_PSK: return "WPA2";
    case WIFI_AUTH_WPA_WPA2_PSK: return "WPA/2";
    case WIFI_AUTH_WPA2_ENTERPRISE: return "WPA2-E";
    case WIFI_AUTH_WPA3_PSK: return "WPA3";
    case WIFI_AUTH_WPA2_WPA3_PSK: return "WPA2/3";
    default: return "?";
  }
}

void wifiScan()
{
  drawHeader("WiFi Scanner");
  display().setCursor(8, 40);
  display().print("Scanning...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(false, true);
  delay(80);
  wifiCount = WiFi.scanNetworks(false, false);  // 受動観測: 接続はしない
  wifiTop = 0;
}

void wifiDraw()
{
  drawHeader("WiFi Scanner");
  if (wifiCount <= 0) {
    display().setCursor(8, 40);
    display().print(wifiCount == 0 ? "No networks found" : "Scan error");
  } else {
    const int rows = 5;
    for (int r = 0; r < rows; ++r) {
      const int i = wifiTop + r;
      if (i >= wifiCount) break;
      const int y = 20 + r * 20;
      display().setTextColor(TFT_WHITE, TFT_BLACK);
      display().setCursor(4, y);
      char line[48];
      String ssid = WiFi.SSID(i);
      if (ssid.isEmpty()) ssid = "<hidden>";
      if (ssid.length() > 16) ssid = ssid.substring(0, 16);
      snprintf(line, sizeof(line), "%-16s", ssid.c_str());
      display().print(line);
      display().setTextColor(WiFi.RSSI(i) > -70 ? TFT_GREEN : TFT_ORANGE, TFT_BLACK);
      display().setCursor(4, y + 9);
      snprintf(line, sizeof(line), "ch%2d %4ddBm %s", WiFi.channel(i), WiFi.RSSI(i),
               authLabel(WiFi.encryptionType(i)));
      display().print(line);
    }
  }
  char hint[40];
  snprintf(hint, sizeof(hint), "%d found  r rescan  ` back", wifiCount < 0 ? 0 : wifiCount);
  drawFooter(hint);
}

void handleWifi(char key)
{
  if (key == KEY_ESC) {
    enterScreen(Screen::Menu);
  } else if (key == 'r') {
    wifiScan();
    wifiDraw();
  } else if (key == KEY_DOWN && wifiTop + 5 < wifiCount) {
    ++wifiTop;
    wifiDraw();
  } else if (key == KEY_UP && wifiTop > 0) {
    --wifiTop;
    wifiDraw();
  }
}

// ---- BLEスキャナ (受動的な広告の観測) --------------------------------
struct BleEntry {
  String name;
  String addr;
  int rssi;
};
std::vector<BleEntry> bleList;
int bleTop = 0;

void bleScan()
{
  drawHeader("BLE Scanner");
  display().setCursor(8, 40);
  display().print("Scanning 4s...");

  BLEDevice::init("");
  BLEScan* scan = BLEDevice::getScan();
  scan->setActiveScan(true);
  scan->setInterval(100);
  scan->setWindow(99);
  BLEScanResults* results = scan->start(4, false);

  bleList.clear();
  const int count = results ? results->getCount() : 0;
  for (int i = 0; i < count; ++i) {
    BLEAdvertisedDevice dev = results->getDevice(i);
    BleEntry entry;
    entry.name = dev.getName().length() ? String(dev.getName().c_str()) : String("<no name>");
    entry.addr = String(dev.getAddress().toString().c_str());
    entry.rssi = dev.getRSSI();
    bleList.push_back(entry);
  }
  scan->clearResults();
  BLEDevice::deinit(false);  // BLEスタックを解放してRAMを戻す
  bleTop = 0;
}

void bleDraw()
{
  drawHeader("BLE Scanner");
  if (bleList.empty()) {
    display().setCursor(8, 40);
    display().print("No devices found");
  } else {
    const int rows = 5;
    for (int r = 0; r < rows; ++r) {
      const size_t i = bleTop + r;
      if (i >= bleList.size()) break;
      const int y = 20 + r * 20;
      display().setTextColor(TFT_WHITE, TFT_BLACK);
      display().setCursor(4, y);
      String name = bleList[i].name;
      if (name.length() > 16) name = name.substring(0, 16);
      display().print(name);
      display().setTextColor(bleList[i].rssi > -75 ? TFT_GREEN : TFT_ORANGE, TFT_BLACK);
      display().setCursor(4, y + 9);
      char line[48];
      snprintf(line, sizeof(line), "%s %ddBm", bleList[i].addr.c_str(), bleList[i].rssi);
      display().print(line);
    }
  }
  char hint[40];
  snprintf(hint, sizeof(hint), "%d found  r rescan  ` back", (int)bleList.size());
  drawFooter(hint);
}

void handleBle(char key)
{
  if (key == KEY_ESC) {
    enterScreen(Screen::Menu);
  } else if (key == 'r') {
    bleScan();
    bleDraw();
  } else if (key == KEY_DOWN && bleTop + 5 < (int)bleList.size()) {
    ++bleTop;
    bleDraw();
  } else if (key == KEY_UP && bleTop > 0) {
    --bleTop;
    bleDraw();
  }
}

// ---- Sysinfo ----------------------------------------------------------
void sysinfoDraw()
{
  drawHeader("System Info");
  display().setTextColor(TFT_WHITE, TFT_BLACK);
  int y = 20;
  auto row = [&](const char* label, const String& value) {
    display().setCursor(4, y);
    display().setTextColor(TFT_CYAN, TFT_BLACK);
    display().print(label);
    display().setTextColor(TFT_WHITE, TFT_BLACK);
    display().print(value);
    y += 15;
  };
  row("Chip : ", String(ESP.getChipModel()) + " x" + String(ESP.getChipCores()));
  row("Flash: ", String(ESP.getFlashChipSize() / (1024 * 1024)) + " MB");
  row("Heap : ", String(ESP.getFreeHeap() / 1024) + " KB free");
  row("WiFi : ", WiFi.macAddress());
  String bt = String(BLEDevice::getAddress().toString().c_str());
  row("BT   : ", bt);
  drawFooter("` back");
}

void handleSysinfo(char key)
{
  if (key == KEY_ESC) {
    enterScreen(Screen::Menu);
  }
}

// ---- Snake (ゲーム) ---------------------------------------------------
constexpr int kCell = 8;
constexpr int kCols = 240 / kCell;   // 30
constexpr int kRows = (135 - 16 - 12) / kCell;  // 盤面高さ(ヘッダ/フッタ除く)
constexpr int kBoardY = 16;

struct Pt { int x; int y; };
std::vector<Pt> snake;
Pt food{0, 0};
Pt dir{1, 0};
bool snakeDead = false;
int snakeScore = 0;
uint32_t snakeStep = 0;

Pt randomCell()
{
  return Pt{(int)(esp_random() % kCols), (int)(esp_random() % kRows)};
}

void placeFood()
{
  while (true) {
    Pt p = randomCell();
    bool onSnake = false;
    for (auto& s : snake) {
      if (s.x == p.x && s.y == p.y) { onSnake = true; break; }
    }
    if (!onSnake) { food = p; return; }
  }
}

void snakeCellDraw(const Pt& p, uint16_t color)
{
  display().fillRect(p.x * kCell, kBoardY + p.y * kCell, kCell - 1, kCell - 1, color);
}

void snakeReset()
{
  snake.clear();
  snake.push_back(Pt{kCols / 2, kRows / 2});
  snake.push_back(Pt{kCols / 2 - 1, kRows / 2});
  dir = Pt{1, 0};
  snakeDead = false;
  snakeScore = 0;
  placeFood();
  drawHeader("Snake  score 0");
  for (auto& s : snake) snakeCellDraw(s, TFT_GREEN);
  snakeCellDraw(food, TFT_RED);
  drawFooter(";,./ move  ` back");
  snakeStep = millis();
}

void snakeTick()
{
  if (snakeDead) return;
  if (millis() - snakeStep < 140) return;
  snakeStep = millis();

  Pt head = snake.front();
  Pt next{head.x + dir.x, head.y + dir.y};

  if (next.x < 0 || next.x >= kCols || next.y < 0 || next.y >= kRows) {
    snakeDead = true;
  }
  for (auto& s : snake) {
    if (s.x == next.x && s.y == next.y) { snakeDead = true; break; }
  }
  if (snakeDead) {
    display().setTextColor(TFT_YELLOW, TFT_BLACK);
    display().setTextDatum(middle_center);
    display().drawString("GAME OVER - enter", display().width() / 2, display().height() / 2);
    display().setTextDatum(top_left);
    return;
  }

  snake.insert(snake.begin(), next);
  snakeCellDraw(next, TFT_GREEN);
  if (next.x == food.x && next.y == food.y) {
    ++snakeScore;
    char t[24];
    snprintf(t, sizeof(t), "Snake  score %d", snakeScore);
    drawHeader(t);
    for (auto& s : snake) snakeCellDraw(s, TFT_GREEN);
    drawFooter(";,./ move  ` back");
    placeFood();
    snakeCellDraw(food, TFT_RED);
  } else {
    Pt tail = snake.back();
    snakeCellDraw(tail, TFT_BLACK);
    snake.pop_back();
  }
}

void handleSnake(char key)
{
  if (key == KEY_ESC) {
    enterScreen(Screen::Menu);
    return;
  }
  if (key == '\r' && snakeDead) {
    snakeReset();
    return;
  }
  // 反転(自分の首へ突っ込む)は無視。
  if (key == KEY_UP && dir.y == 0) dir = Pt{0, -1};
  else if (key == KEY_DOWN && dir.y == 0) dir = Pt{0, 1};
  else if (key == KEY_LEFT && dir.x == 0) dir = Pt{-1, 0};
  else if (key == KEY_RIGHT && dir.x == 0) dir = Pt{1, 0};
}

// ---- 画面遷移 ---------------------------------------------------------
void enterScreen(Screen next)
{
  screen = next;
  switch (next) {
    case Screen::Menu: drawMenu(); break;
    case Screen::Wifi: wifiScan(); wifiDraw(); break;
    case Screen::Ble: bleScan(); bleDraw(); break;
    case Screen::Sysinfo: sysinfoDraw(); break;
    case Screen::Snake: snakeReset(); break;
  }
}

}  // namespace

void setup()
{
  auto config = M5.config();
  config.internal_spk = false;  // 本ツールは音を使わない。
  M5Cardputer.begin(config);
  M5Cardputer.Display.setRotation(1);
  M5Cardputer.Display.setFont(&fonts::Font2);
  M5Cardputer.Display.setTextSize(1);
  enterScreen(Screen::Menu);
}

void loop()
{
  M5Cardputer.update();
  char key = pollKey();

  switch (screen) {
    case Screen::Menu: if (key) handleMenu(key); break;
    case Screen::Wifi: if (key) handleWifi(key); break;
    case Screen::Ble: if (key) handleBle(key); break;
    case Screen::Sysinfo: if (key) handleSysinfo(key); break;
    case Screen::Snake:
      if (key) handleSnake(key);
      snakeTick();
      break;
  }
  delay(5);
}
