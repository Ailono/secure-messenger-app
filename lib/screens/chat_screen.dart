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
  final WebSocketChannel channel;
  final Crypto crypto;
  final String username, peer;
  final Map<String, dynamic> sharedState;

  const ChatScreen({super.key, required this.channel, required this.crypto,
    required this.username, required this.peer, required this.sharedState});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  Uint8List? _peerPublicKey;
  bool _keySent = false;
  String _status = '🔑 Обмен ключами...';
  Color _statusColor = const Color(0xFFF0A500);

  @override
  void initState() {
    super.initState();
    // Register callback for incoming packets
    widget.sharedState['callback_${widget.peer}'] = _onPacket;
    // Process any pending packets
    final pending = widget.sharedState['pending_${widget.peer}'] as List? ?? [];
    for (final pkt in pending) _onPacket(pkt);
    widget.sharedState.remove('pending_${widget.peer}');
    // Initiate key exchange
    _sendKeyExchange();
  }

  void _sendKeyExchange() {
    _keySent = true;
    widget.channel.sink.add(jsonEncode({
      'type': 'key_exchange',
      'from': widget.username,
      'to': widget.peer,
      'pubkey': widget.crypto.exportPublicKey(),
    }));
  }

  void _onPacket(dynamic pkt) {
    if (!mounted) return;
    if (pkt['type'] == 'key_exchange') {
      _peerPublicKey = base64Decode(pkt['pubkey'] as String);
      setState(() { _status = '🔒 Зашифровано (E2E)'; _statusColor = Colors.green; });
      if (!_keySent) _sendKeyExchange();
    } else if (pkt['type'] == 'message') {
      if (_peerPublicKey == null) return;
      try {
        final text = widget.crypto.decrypt(pkt['data'] as String, _peerPublicKey!);
        setState(() => _messages.add(Message(pkt['from'] as String, text)));
        _scrollToBottom();
      } catch (_) {}
    }
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _peerPublicKey == null) return;
    final data = widget.crypto.encrypt(text, _peerPublicKey!);
    widget.channel.sink.add(jsonEncode({'type': 'message', 'from': widget.username, 'to': widget.peer, 'data': data}));
    setState(() => _messages.add(Message(widget.username, text)));
    _inputCtrl.clear();
    _scrollToBottom();
  }

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
    widget.sharedState.remove('callback_${widget.peer}');
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D3D),
        leading: const BackButton(color: Color(0xFF5B9BD5)),
        title: Row(children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF2B5278), radius: 18,
            child: Text(widget.peer[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.peer, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(_status, style: TextStyle(fontSize: 11, color: _statusColor)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: _messages.length,
          itemBuilder: (_, i) => _buildBubble(_messages[i]),
        )),
        _buildInput(),
      ]),
    );
  }

  Widget _buildBubble(Message msg) {
    final isMine = msg.sender == widget.username;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: 4, bottom: 4, left: isMine ? 60 : 0, right: isMine ? 0 : 60),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF2B5278) : const Color(0xFF1E2D3D),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14), topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(
            '${msg.time.hour.toString().padLeft(2,'0')}:${msg.time.minute.toString().padLeft(2,'0')}',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ]),
      ),
    );
  }

  Widget _buildInput() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: const Color(0xFF1E2D3D),
    child: Row(children: [
      Expanded(child: TextField(
        controller: _inputCtrl,
        style: const TextStyle(color: Colors.white),
        onSubmitted: (_) => _sendMessage(),
        decoration: InputDecoration(
          hintText: 'Сообщение...', hintStyle: const TextStyle(color: Colors.grey),
          filled: true, fillColor: const Color(0xFF16212E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        ),
      )),
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
