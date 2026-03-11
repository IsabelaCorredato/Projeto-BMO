#include <WiFi.h>
#include <WebSocketsClient.h>
#include <Keypad.h>

#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""
#define WIFI_CHANNEL 6

WebSocketsClient webSocket;

const char* address = "host.wokwi.internal";
const uint16_t port = 45455;
const char* route = "/ws";

// -------------------------
// Keypad 4x4
// -------------------------
const byte ROWS = 4;
const byte COLS = 4;

char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};

// ajuste os pinos conforme o diagram.json
byte rowPins[ROWS] = {23, 22, 21, 19};
byte colPins[COLS] = {18, 5, 17, 16};

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

bool wsConnected = false;

void sendKeyMessage(char key) {
  if (!wsConnected) {
    Serial.println("[WSc] WS nao conectado. Tecla ignorada.");
    return;
  }

  String json = "{\"text\":\"tecla ";
  json += key;
  json += "\",\"source\":\"esp32\"}";

  webSocket.sendTXT(json);
  Serial.print("[WSc] Enviado: ");
  Serial.println(json);
}

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      wsConnected = false;
      Serial.println("[WSc] Disconnected!");
      break;

    case WStype_CONNECTED:
      wsConnected = true;
      Serial.printf("[WSc] Connected: %s\n", payload);

      webSocket.sendTXT(
        "{\"text\":\"mensagem para teste do esp32 wokwi\",\"source\":\"esp32\"}"
      );
      break;

    case WStype_TEXT:
      Serial.printf("[WSc] Recebido: %s\n", payload);
      break;

    case WStype_ERROR:
      wsConnected = false;
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

  char key = keypad.getKey();
  if (key) {
    Serial.print("[KEYPAD] Tecla pressionada: ");
    Serial.println(key);
    sendKeyMessage(key);
  }
}