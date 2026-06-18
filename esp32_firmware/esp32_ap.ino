# Simple ESP32 SoftAP firmware (Arduino)

/*
  esp32_ap.ino
  Simple ESP32 SoftAP that creates an SSID with a prefix and serves a basic HTTP page on port 80.

  - Edit SSID_PREFIX and AP_PASSWORD as needed.
  - If AP_PASSWORD is empty, the AP is open (no password).
  - Upload with Arduino IDE (ESP32 boards) or PlatformIO.
*/

#include <WiFi.h>
#include <WebServer.h>

// Configuration
#define SSID_PREFIX "ESP32"
#define AP_PASSWORD "" // empty => open AP
#define AP_CHANNEL 1

WebServer server(80);

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
  body += "</body></html>";
  server.send(200, "text/html", body);
}

void setup() {
  Serial.begin(115200);
  delay(500);
  String ssid = makeSSID();
  Serial.println();
  Serial.print("Starting SoftAP with SSID: "); Serial.println(ssid);

  if (strlen(AP_PASSWORD) == 0) {
    // Open AP
    WiFi.softAP(ssid.c_str(), NULL, AP_CHANNEL);
  } else {
    WiFi.softAP(ssid.c_str(), AP_PASSWORD, AP_CHANNEL);
  }

  IPAddress ip = WiFi.softAPIP();
  Serial.print("AP IP address: "); Serial.println(ip);

  server.on("/", handleRoot);
  server.begin();
  Serial.println("HTTP server started on port 80");
}

void loop() {
  server.handleClient();
}
