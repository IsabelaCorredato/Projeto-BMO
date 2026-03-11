import 'package:flutter/material.dart';

import 'controllers/bmo_controller.dart';
import 'models/chat_message.dart';
import 'services/chat_database.dart';
import 'services/esp32_websocket_service.dart';
import 'services/gemini_service.dart';
import 'services/node_messages_api_service.dart';

const _geminiApiKey = 'AIzaSyBn-OQgFAe9Fp2HGSOmiT_AoWHr6noeOy8';
const _defaultApiToken = 'bmo-local-123';
const _defaultNodeApiBaseUrl = String.fromEnvironment(
  'NODE_API_BASE_URL',
  defaultValue: 'https://nonprivileged-jamie-bottomless.ngrok-free.dev',
);
const _defaultNodeWsUrl = String.fromEnvironment(
  'NODE_WS_URL',
  defaultValue: 'wss://nonprivileged-jamie-bottomless.ngrok-free.dev/ws',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BmoApp());
}

class BmoApp extends StatelessWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BMO Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF44B9B0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFE8F7F1),
        useMaterial3: true,
      ),
      home: const BmoHomePage(),
    );
  }
}

class BmoHomePage extends StatefulWidget {
  const BmoHomePage({super.key});

  @override
  State<BmoHomePage> createState() => _BmoHomePageState();
}

class _BmoHomePageState extends State<BmoHomePage> {
  late final BmoController _controller;
  final TextEditingController _wsController = TextEditingController(
    text: _defaultNodeWsUrl,
  );
  final TextEditingController _apiController = TextEditingController(
    text: _defaultNodeApiBaseUrl,
  );
  final TextEditingController _tokenController = TextEditingController(
    text: _defaultApiToken,
  );
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = BmoController(
      database: ChatDatabase(),
      gemini: GeminiService(apiKey: _geminiApiKey),
      websocket: Esp32WebSocketService(),
      nodeApi: NodeMessagesApiService(),
    );

    _controller.addListener(_autoScroll);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_autoScroll);
    _controller.dispose();
    _wsController.dispose();
    _apiController.dispose();
    _tokenController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) {
      return;
    }

    _messageController.clear();
    await _controller.sendUserMessage(text);
  }

  Future<void> _toggleConnection() async {
    if (_controller.isConnected) {
      await _controller.disconnectFromNode();
      return;
    }

    await _controller.connectToNode(
      wsUrl: _wsController.text,
      apiBaseUrl: _apiController.text,
      apiToken: _tokenController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final hasError = _controller.errorText != null;
        final headerItems = 1 + (hasError ? 1 : 0);
        final thinkingItems = _controller.isGenerating ? 1 : 0;
        final totalItems =
            headerItems + _controller.messages.length + thinkingItems;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('BMO Bridge'),
            actions: [
              IconButton(
                onPressed: _controller.messages.isEmpty
                    ? null
                    : () => _controller.clearContext(),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Limpar contexto (SQLite)',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 12),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildConnectionPanel();
                    }

                    var offset = 1;

                    if (hasError) {
                      if (index == offset) {
                        return _buildErrorBanner(
                          context,
                          _controller.errorText!,
                        );
                      }
                      offset++;
                    }

                    final messageIndex = index - offset;
                    if (messageIndex >= 0 &&
                        messageIndex < _controller.messages.length) {
                      final message = _controller.messages[messageIndex];
                      return _MessageBubble(message: message);
                    }

                    return const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('BMO está pensando...'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildComposer(),
        );
      },
    );
  }

  Widget _buildErrorBanner(BuildContext context, String errorText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          errorText,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionPanel() {
    final statusColor = switch (_controller.statusText) {
      'Conectado' => Colors.green,
      'Conectando...' => Colors.orange,
      _ => Colors.red,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _controller.statusText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _toggleConnection,
                    child: Text(
                      _controller.isConnected ? 'Desconectar' : 'Conectar',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _wsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Node WS URL',
                  hintText: 'Opcional se API URL estiver preenchida',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Node API base URL',
                  hintText: 'https://<codespace>-8080.app.github.dev',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Bearer token API',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => _controller.syncMessagesFromApi(),
                  child: const Text('Sincronizar API /messages'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        bottomPadding > 0 ? bottomPadding : 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: const InputDecoration(
                hintText: 'Digite uma mensagem para o BMO / Node',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _handleSend, child: const Text('Enviar')),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.source == MessageSource.user;
    final isBmo = message.source == MessageSource.bmo;
    final isSystem = message.source == MessageSource.system;

    final backgroundColor = isSystem
        ? Colors.blueGrey.shade100
        : isUser
        ? const Color(0xFFA0E8D6)
        : isBmo
        ? const Color(0xFFB2F2B4)
        : Colors.white;

    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sourceLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(message.text),
          ],
        ),
      ),
    );
  }
}
