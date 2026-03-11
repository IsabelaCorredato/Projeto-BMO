const http = require("http");
const WebSocket = require("ws");

const LOCAL_PORT = 45455;
const REMOTE_URL = "wss://nonprivileged-jamie-bottomless.ngrok-free.dev/ws";

const server = http.createServer();
const localWss = new WebSocket.Server({ server, path: "/ws" });

console.log("[bridge] iniciando...");

localWss.on("connection", (espWs, req) => {
  console.log("[bridge] ESP conectado:", req.url);

  const remoteWs = new WebSocket(REMOTE_URL);

  remoteWs.on("open", () => {
    console.log("[bridge] conectado no servidor remoto WSS");
  });

  remoteWs.on("message", (data) => {
    const text = data.toString();
    console.log("[remote -> esp]", text);

    if (espWs.readyState === WebSocket.OPEN) {
      espWs.send(text);
    }
  });

  remoteWs.on("close", (code, reason) => {
    console.log("[bridge] remoto fechou:", code, reason.toString());
    if (espWs.readyState === WebSocket.OPEN) {
      espWs.close();
    }
  });

  remoteWs.on("error", (err) => {
    console.log("[bridge] erro remoto:", err.message);
  });

  espWs.on("message", (data) => {
    const text = data.toString();
    console.log("[esp -> remote]", text);

    if (remoteWs.readyState === WebSocket.OPEN) {
      remoteWs.send(text);
    }
  });

  espWs.on("close", () => {
    console.log("[bridge] ESP desconectou");
    if (remoteWs.readyState === WebSocket.OPEN) {
      remoteWs.close();
    }
  });

  espWs.on("error", (err) => {
    console.log("[bridge] erro ESP:", err.message);
  });
});

server.listen(LOCAL_PORT, "0.0.0.0", () => {
  console.log(`[bridge] ws local em ws://localhost:${LOCAL_PORT}/ws`);
});