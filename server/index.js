const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

const PORT = Number(process.env.PORT || 8080);
const API_TOKEN = (process.env.API_TOKEN || 'bmo-local-123').trim();
const MAX_IN_MEMORY_MESSAGES = Number(process.env.MAX_IN_MEMORY_MESSAGES || 300);
const CODESPACE_NAME = (process.env.CODESPACE_NAME || '').trim();
const FORWARDING_DOMAIN = (process.env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN || '').trim();

const messages = [];
let nextId = 1;

function createMessage({ text, source }) {
  const message = {
    id: nextId++,
    source: source || 'unknown',
    text,
    createdAt: new Date().toISOString(),
  };

  messages.push(message);
  const maxItems = Number.isFinite(MAX_IN_MEMORY_MESSAGES)
    ? Math.max(1, Math.trunc(MAX_IN_MEMORY_MESSAGES))
    : 300;
  if (messages.length > maxItems) {
    messages.shift();
  }
  return message;
}

const app = express();
app.use(cors());
app.use(express.json());

function requireAuth(req, res, next) {
  if (!API_TOKEN) {
    return res.status(503).json({
      error: 'api_token_missing',
      message: 'Configure API_TOKEN no servidor Node',
    });
  }

  const auth = req.headers.authorization || '';
  if (auth !== `Bearer ${API_TOKEN}`) {
    return res.status(401).json({
      error: 'unauthorized',
      message: 'Use Authorization: Bearer <TOKEN>',
    });
  }

  return next();
}

app.get('/health', (req, res) => {
  const publicHttpUrl =
    CODESPACE_NAME && FORWARDING_DOMAIN
      ? `https://${CODESPACE_NAME}-${PORT}.${FORWARDING_DOMAIN}`
      : null;

  const publicWsUrl =
    CODESPACE_NAME && FORWARDING_DOMAIN
      ? `wss://${CODESPACE_NAME}-${PORT}.${FORWARDING_DOMAIN}/ws`
      : null;

  res.json({
    status: 'ok',
    wsPath: '/ws (ou /)',
    messages: messages.length,
    apiTokenConfigured: Boolean(API_TOKEN),
    publicHttpUrl,
    publicWsUrl,
  });
});

app.get('/messages', requireAuth, (req, res) => {
  const rawLimit = Number(req.query.limit || 50);
  const limit = Number.isFinite(rawLimit)
    ? Math.max(1, Math.min(300, Math.trunc(rawLimit)))
    : 50;

  const items = messages.slice(-limit);
  res.json({ count: items.length, data: items });
});

app.post('/messages', requireAuth, (req, res) => {
  const text = String(req.body?.text || '').trim();
  const source = String(req.body?.source || 'api').trim();

  if (!text) {
    return res.status(400).json({ error: 'text_required' });
  }

  const created = createMessage({ text, source });
  console.log(`[api] message id=${created.id} source=${created.source}`);
  broadcast({ type: 'message', data: created });
  return res.status(201).json({ data: created });
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ noServer: true });

function broadcast(payload, options = {}) {
  const exclude = options.exclude;
  const encoded = JSON.stringify(payload);

  for (const client of wss.clients) {
    if (client.readyState !== WebSocket.OPEN) {
      continue;
    }

    if (exclude && client === exclude) {
      continue;
    }

    client.send(encoded);
  }
}

server.on('upgrade', (request, socket, head) => {
  const pathname = new URL(request.url || '/', 'http://localhost').pathname;
  if (pathname !== '/' && pathname !== '/ws') {
    socket.destroy();
    return;
  }

  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws);
  });
});

wss.on('connection', (ws) => {
  ws.on('message', (data) => {
    const raw = String(data || '').trim();
    if (!raw) {
      return;
    }

    let text = raw;
    let source = 'esp32';

    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object') {
        text = String(parsed.text || '').trim();
        source = String(parsed.source || 'esp32').trim();
      }
    } catch {
      // Mensagem em texto puro (ex.: ESP32)
    }

    if (!text) {
      return;
    }

    const created = createMessage({ text, source });
    console.log(`[ws] message id=${created.id} source=${created.source}`);

    // Envia para os outros clientes (evita eco no emissor).
    broadcast({ type: 'message', data: created }, { exclude: ws });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[bmo-node] listening on http://0.0.0.0:${PORT}`);
  console.log(`[bmo-node] ws endpoint: ws://<host>:${PORT}/ws`);
  if (CODESPACE_NAME && FORWARDING_DOMAIN) {
    const publicHost = `${CODESPACE_NAME}-${PORT}.${FORWARDING_DOMAIN}`;
    console.log(`[bmo-node] codespaces http: https://${publicHost}`);
    console.log(`[bmo-node] codespaces ws:   wss://${publicHost}/ws`);
  }
});
