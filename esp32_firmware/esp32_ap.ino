// Simple ESP32 SoftAP firmware (Arduino)

/*
  esp32_ap.ino
  Simple ESP32 SoftAP that creates an SSID with a prefix and serves a basic HTTP page on port 80.

  - Edit SSID_PREFIX and AP_PASSWORD as needed.
  - If AP_PASSWORD is empty, the AP is open (no password).
  - By default this sketch configures a static IP for the SoftAP (192.168.4.1).
  - Upload with Arduino IDE (ESP32 boards) or PlatformIO.
*/

#include <WiFi.h>
#include <WebServer.h>

// Configuration
#define SSID_PREFIX "ESP32"
#define AP_PASSWORD "" // empty => open AP
#define AP_CHANNEL 1

// Static IP configuration for SoftAP
#define USE_STATIC_IP 1
#define AP_IP 192,168,4,1
#define AP_GATEWAY 192,168,4,1
#define AP_SUBNET 255,255,255,0

WebServer server(80);
const int LED_PIN = 2; // onboard LED (change if your board uses different pin)

String makeSSID() {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  char tail[9];
  sprintf(tail, "%02X%02X", mac[4], mac[5]);
  String ssid = String(SSID_PREFIX) + "-" + String(tail);
  return ssid;
}

void handleRoot() {
  IPAddress ip = WiFi.softAPIP();
  String body = "<html><head><meta charset=\"utf-8\"></head><body>";
  body += "<h2>ESP32 AP</h2>";
  body += "<p>SSID: " + WiFi.softAPSSID() + "</p>";
  body += "<p>IP: " + ip.toString() + "</p>";
  body += "<p>Stations: " + String(WiFi.softAPgetStationNum()) + "</p>";
  body += "</body></html>";
  server.send(200, "text/html", body);
}

void handleStatus() {
  String body = "stations=" + String(WiFi.softAPgetStationNum());
  server.send(200, "text/plain", body);
}

// Fallback polling to detect client connect/disconnect events.
// Some ESP32 Arduino core versions changed the WiFi event API; using softAPgetStationNum()
// polling is robust across versions.
static int lastStationCount = 0;
static unsigned long lastCheckMillis = 0;
const unsigned long CHECK_INTERVAL = 500; // ms

void notifyClientConnected(int newCount){
  Serial.print("[ESP32] Stations changed: ");
  Serial.print(lastStationCount);
  Serial.print(" -> ");
  Serial.println(newCount);
  if(newCount > lastStationCount){
    Serial.println("[ESP32] 接続完了");
    // blink LED to indicate connection
    digitalWrite(LED_PIN, HIGH);
    delay(200);
    digitalWrite(LED_PIN, LOW);
  } else if(newCount < lastStationCount){
    Serial.println("[ESP32] 切断検出");
  }
  lastStationCount = newCount;
}

void setup() {
  Serial.begin(115200);
  delay(500);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  String ssid = makeSSID();
  Serial.println();
  Serial.print("Starting SoftAP with SSID: "); Serial.println(ssid);

#if USE_STATIC_IP
  IPAddress localIP(AP_IP);
  IPAddress gateway(AP_GATEWAY);
  IPAddress subnet(AP_SUBNET);
  bool ok = WiFi.softAPConfig(localIP, gateway, subnet);
  if(!ok) {
    Serial.println("softAPConfig failed");
  } else {
    Serial.print("Configured SoftAP static IP: "); Serial.println(localIP);
  }
#endif

  if (strlen(AP_PASSWORD) == 0) {
    // Open AP
    WiFi.softAP(ssid.c_str(), NULL, AP_CHANNEL);
  } else {
    WiFi.softAP(ssid.c_str(), AP_PASSWORD, AP_CHANNEL);
  }

  // initialize station count
  lastStationCount = WiFi.softAPgetStationNum();

  IPAddress ip = WiFi.softAPIP();
  Serial.print("AP IP address: "); Serial.println(ip);

  server.on("/", handleRoot);
  server.on("/status", handleStatus);
  server.begin();
  Serial.println("HTTP server started on port 80");
}

void loop() {
  server.handleClient();

  unsigned long now = millis();
  if(now - lastCheckMillis >= CHECK_INTERVAL){
    lastCheckMillis = now;
    int count = WiFi.softAPgetStationNum();
    if(count != lastStationCount){
      notifyClientConnected(count);
    }
  }
}
