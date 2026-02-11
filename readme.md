# BMO Assistant (FireTV + ESP32 + Gemini)

Assistente interativo inspirado no BMO (*Adventure Time*), utilizando **ESP32**, **Fire TV** e **IA generativa (Gemini API)** para criar um dispositivo físico capaz de capturar voz, processar comandos e responder por áudio e interface visual.

---

# Arquitetura do Sistema

O sistema é dividido em três partes principais:

* ESP32 (hardware e captura de áudio)
* App no Fire TV (interface e processamento)
* API Gemini (IA)

Arquitetura geral:

```
Microfone → ESP32 → WebSocket → App FireTV → Gemini API
                                      ↓
ESP32 ← WebSocket ← resposta IA ← processamento
```

---

# Fluxo de funcionamento

1. O usuário fala no microfone conectado ao ESP32.
2. O ESP32 captura o áudio.
3. O ESP32 envia os dados via WebSocket para o app no Fire TV.
4. O app no Fire TV envia o conteúdo para a API do Gemini.
5. A API retorna a resposta gerada pela IA.
6. O app envia a resposta de volta via WebSocket para o ESP32.
7. O ESP32:

   * reproduz o áudio no alto-falante
   * exibe informações no display
8. O Fire TV atualiza a interface visual do BMO.

---

# Componentes utilizados

## Hardware

* ESP32-S3
* Microfone I2S (INMP441)
* Amplificador MAX98357A
* Speaker 3W
* Display OLED SSD1306
* Botão físico
* Protoboard e jumpers

## Software

* Firmware ESP32 (C++ / Arduino / ESP-IDF)
* App Fire TV (Flutter ou Android)
* WebSocket para comunicação
* Gemini API para IA

---

# Tecnologias utilizadas

## Comunicação

* WebSocket
* JSON

## Linguagens

* C++
* Dart / Kotlin
* HTTP / REST

## IA

* Gemini API (Google AI)

---

# Formato de dados (JSON)

Mensagem enviada pelo ESP32:

```json
{
  "type": "audio",
  "data": "base64_audio_chunk"
}
```

Resposta do app:

```json
{
  "type": "response",
  "text": "Olá! Eu sou o BMO!",
  "audio": "base64_audio"
}
```

Mensagem para o display:

```json
{
  "type": "display",
  "text": "Respondendo..."
}
```

---

# Banco de dados

Este protótipo não utiliza banco de dados persistente.
O estado da conversa é mantido em memória no aplicativo Fire TV.

Possíveis evoluções:

* SQLite
* Firebase
* Supabase

---

# API utilizada

Gemini API (Google AI)

Responsável por:

* processamento de linguagem natural
* geração de respostas
* lógica conversacional

---

# Plataforma de prototipagem

Wokwi será utilizado para:

* simular ESP32
* testar conexões básicas
* validar lógica inicial

Motivo:

* rápida prototipagem
* não requer hardware físico
* fácil integração com ESP32

---

# Objetivo do projeto

Criar um assistente físico com IA capaz de:

* capturar voz
* interpretar comandos
* responder com áudio
* exibir informações no display
* apresentar interface animada no Fire TV

