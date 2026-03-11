# BMO Bridge (Codespaces Ready)

App Flutter (cliente) + backend Node (WebSocket + API `/messages`) para integrar BMO/ESP32.

## Backend Node

```bash
cd server
npm install
npm start
```

Variáveis opcionais:
- `PORT` (default `8080`)
- `API_TOKEN` (default `bmo-local-123`)
- `MAX_IN_MEMORY_MESSAGES` (default `300`)

Observação:
- O backend Node **não salva mensagens em arquivo/disco**.
- O histórico/contexto persistente fica no SQLite do app Flutter.

Endpoints:
- `GET /health`
- `GET /messages?limit=50` (Bearer)
- `POST /messages` (Bearer)
- WebSocket em `/ws`

## GitHub Codespaces

1. Suba o backend em `PORT=8080`.
2. No painel de portas do Codespaces, deixe a porta `8080` como **Public**.
3. Use a URL pública HTTPS do Codespace (exemplo):

```text
https://<codespace>-8080.app.github.dev
```

4. O WebSocket correspondente será:

```text
wss://<codespace>-8080.app.github.dev/ws
```

Obs: o `GET /health` já retorna `publicHttpUrl` e `publicWsUrl` quando rodando em Codespaces.

## App Flutter

```bash
flutter pub get
flutter run -d <device_id>
```

No app:
- `Node API base URL`: `https://<codespace>-8080.app.github.dev`
- `Bearer token API`: `bmo-local-123` (ou seu token)
- `Node WS URL`: opcional; se vazio, o app deriva automaticamente de API URL (`https -> wss`, `http -> ws`).

Também é possível pré-preencher via `dart-define`:

```bash
flutter run -d <device_id> \
  --dart-define=NODE_API_BASE_URL=https://<codespace>-8080.app.github.dev
```

## Testes rápidos

```bash
curl -H "Authorization: Bearer bmo-local-123" \
  "https://<codespace>-8080.app.github.dev/messages?limit=20"

curl -X POST "https://<codespace>-8080.app.github.dev/messages" \
  -H "Authorization: Bearer bmo-local-123" \
  -H "Content-Type: application/json" \
  -d '{"text":"oi bmo","source":"api"}'
```
