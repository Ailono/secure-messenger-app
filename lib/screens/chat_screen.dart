import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../crypto.dart';

class Message {
  final String sender, text;
  final DateTime time;
  Message(this.sender, this.text) : time = DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final String server, username, peer;
  const ChatScreen({super.key, required this.server, required this.username, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late WebSocketChannel _channel;
  final _crypto = Crypto();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  Uint8List? _peerPublicKey;
  bool _keySent = false;
  String _status = 'Ожидание собеседника...';
  Color _statusColor = const Color(0xFFF0A500);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    final uri = Uri.parse('ws://${widget.server}/ws');
    _channel = WebSocketChannel.connect(uri);

    _channel.stream.listen(_onPacket, onError: (_) {
      setState(() { _status = 'Ошибка соединения'; _statusColor = Colors.redAccent; });
    }, onDone: () {
      setState(() { _status = 'Соединение потеряно'; _statusColor = Colors.redAccent; });
    });

    _channel.sink.add(jsonEncode({'type': 'register', 'username': widget.username, 'recipient': widget.peer}));
  }

  void _onPacket(dynamic raw) {
    final pkt = jsonDecode(raw as String);
    switch (pkt['type']) {
      case 'peer_online':
        _sendKeyExchange();
        break;
      case 'key_exchange':
        _peerPublicKey = base64Decode(pkt['pubkey'] as String);
        setState(() { _status = '🔒 Зашифровано (E2E)'; _statusColor = Colors.green; });
        if (!_keySent) _sendKeyExchange();
        break;
      case 'message':
        if (_peerPublicKey == null) return;
        try {
          final text = _crypto.decrypt(pkt['data'] as String, _peerPublicKey!);
          setState(() => _messages.add(Message(pkt['from'] as String, text)));
          _scrollToBottom();
        } catch (_) {}
        break;
      case 'error':
        _addSys('⚠️ ${pkt['msg']}');
        break;
    }
  }

  void _sendKeyExchange() {
    _keySent = true;
    _channel.sink.add(jsonEncode({
      'type': 'key_exchange',
      'from': widget.username,
      'to': widget.peer,
      'pubkey': _crypto.exportPublicKey(),
    }));
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _peerPublicKey == null) return;

    final data = _crypto.encrypt(text, _peerPublicKey!);
    _channel.sink.add(jsonEncode({'type': 'message', 'from': widget.username, 'to': widget.peer, 'data': data}));
    setState(() => _messages.add(Message(widget.username, text)));
    _inputCtrl.clear();
    _scrollToBottom();
  }

  void _addSys(String text) => setState(() => _messages.add(Message('', text)));

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D3D),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.peer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_status, style: TextStyle(fontSize: 11, color: _statusColor)),
        ]),
        leading: const BackButton(color: Color(0xFF5B9BD5)),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (_, i) => _buildBubble(_messages[i]),
          ),
        ),
        _buildInput(),
      ]),
    );
  }

  Widget _buildBubble(Message msg) {
    final isMine = msg.sender == widget.username;
    final isSys  = msg.sender.isEmpty;

    if (isSys) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(child: Text(msg.text, style: const TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4, bottom: 4,
          left: isMine ? 60 : 0,
          right: isMine ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF2B5278) : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (!isMine)
            Text(msg.sender, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(
            '${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ]),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E2D3D),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputCtrl,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Сообщение...',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF16212E),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFF2B5278), shape: BoxShape.circle),
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}
