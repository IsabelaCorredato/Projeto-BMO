#include <WiFi.h>
#include <WebSocketsClient.h>

#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""
#define WIFI_CHANNEL 6

WebSocketsClient webSocket;

const char* address = "host.wokwi.internal";
const uint16_t port = 45455;
const char* route = "/ws";

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("[WSc] Disconnected!");
      break;

    case WStype_CONNECTED:

      Serial.printf("[WSc] Connected: %s\n", payload);

      webSocket.sendTXT(
        "{\"text\":\"mensagem do esp32 wokwi\",\"source\":\"esp32\"}"
      );

      break;

    case WStype_TEXT:
      Serial.printf("[WSc] Recebido: %s\n", payload);
      break;

    case WStype_ERROR:
      Serial.println("[WSc] Error!");
      break;

    default:
      break;
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD, WIFI_CHANNEL);
  Serial.print("Connecting to WiFi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(200);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi connected!");
  Serial.println(WiFi.localIP());

  webSocket.begin(address, port, route);
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);

  Serial.println("WebSocket configurado");
}

void loop() {
  webSocket.loop();
}