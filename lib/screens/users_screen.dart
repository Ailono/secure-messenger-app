import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../crypto.dart';
import 'chat_screen.dart';

class UsersScreen extends StatefulWidget {
  final String server, username, token;
  const UsersScreen({super.key, required this.server, required this.username, required this.token});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late WebSocketChannel _channel;
  final _crypto = Crypto();
  List<String> _users = [];
  bool _connected = false;

  // Shared state passed to chat screens
  final Map<String, dynamic> _sharedState = {};

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    // WSS with JWT token — server rejects unauthorized connections
    final uri = Uri.parse('wss://${widget.server}/ws?token=${Uri.encodeComponent(widget.token)}');
    _channel = WebSocketChannel.connect(uri);
    _channel.stream.listen(_onPacket, onError: (_) {
      setState(() => _connected = false);
    });
  }

  void _onPacket(dynamic raw) {
    final pkt = jsonDecode(raw as String);
    if (pkt['type'] == 'ack') {
      setState(() => _connected = true);
    } else if (pkt['type'] == 'users') {
      setState(() => _users = List<String>.from(pkt['users']));
    } else if (pkt['type'] == 'key_exchange' || pkt['type'] == 'message') {
      // Forward to active chat if open
      _sharedState['pending_${pkt['from']}'] ??= [];
      (_sharedState['pending_${pkt['from']}'] as List).add(pkt);
      _sharedState['callback_${pkt['from']}']?.call(pkt);
    }
  }

  void _openChat(String peer) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        channel: _channel,
        crypto: _crypto,
        username: widget.username,
        peer: peer,
        sharedState: _sharedState,
      ),
    ));
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2535),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💬 Secure Messenger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5B9BD5))),
          Text(widget.username, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _connected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      body: _users.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('👥', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(_connected ? 'Нет пользователей онлайн' : 'Подключение...', style: const TextStyle(color: Colors.grey)),
          ]))
        : ListView.builder(
            itemCount: _users.length,
            itemBuilder: (_, i) {
              final peer = _users[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2B5278),
                  child: Text(peer[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(peer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Нажмите чтобы написать', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () => _openChat(peer),
                tileColor: const Color(0xFF1A2535),
              );
            },
          ),
    );
  }
}
