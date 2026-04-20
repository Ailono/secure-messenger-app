import 'dart:convert';
import 'dart:io';
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

class _UsersScreenState extends State<UsersScreen> with SingleTickerProviderStateMixin {
  late WebSocketChannel _channel;
  late TabController _tabController;
  Crypto? _crypto;
  final Map<String, dynamic> _sharedState = {};

  List<String> _allUsers = [];
  List<Map<String, dynamic>> _conversations = [];
  List<String> _onlineUsers = [];
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Crypto.init(widget.username).then((c) {
      if (mounted) setState(() => _crypto = c);
    });
    _connect();
    _loadPeople();
    _loadConversations();
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse('https://${widget.server}$path?token=${Uri.encodeComponent(widget.token)}');
      final req  = await client.getUrl(uri);
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  Future<void> _loadPeople() async {
    final data = await _getJson('/users');
    if (data == null || !mounted) return;
    setState(() {
      _allUsers    = List<String>.from(data['users']  ?? []);
      _onlineUsers = List<String>.from(data['online'] ?? []);
    });
  }

  Future<void> _loadConversations() async {
    final data = await _getJson('/conversations');
    if (data == null || !mounted) return;
    setState(() {
      _conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
      _onlineUsers   = List<String>.from(data['online'] ?? []);
    });
  }

  void _connect() {
    final uri = Uri.parse('wss://${widget.server}/ws?token=${Uri.encodeComponent(widget.token)}');
    _channel = WebSocketChannel.connect(uri);
    _channel.stream.listen(_onPacket, onError: (_) => setState(() => _connected = false));
  }

  void _onPacket(dynamic raw) {
    final pkt = jsonDecode(raw as String);
    if (pkt['type'] == 'ack') {
      setState(() => _connected = true);
    } else if (pkt['type'] == 'online') {
      setState(() => _onlineUsers = List<String>.from(pkt['users'] ?? []));
      _loadConversations();
    } else if (['key_exchange', 'key_ratchet', 'message'].contains(pkt['type'])) {
      final from = pkt['from'] as String?;
      if (from == null) return;
      _sharedState['pending_$from'] ??= [];
      (_sharedState['pending_$from'] as List).add(pkt);
      (_sharedState['callback_$from'] as Function?)?.call(pkt);
    }
  }

  void _openChat(String peer) {
    if (_crypto == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        channel: _channel, crypto: _crypto!,
        username: widget.username, peer: peer,
        server: widget.server, token: widget.token,
        sharedState: _sharedState,
        onConversationUpdated: _loadConversations,
      ),
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2535),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🔒 Secure Messenger',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5B9BD5))),
          Text(widget.username, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        automaticallyImplyLeading: false,
        actions: [
          Container(margin: const EdgeInsets.only(right: 16), width: 8, height: 8,
            decoration: BoxDecoration(
              color: _connected ? Colors.green : Colors.red, shape: BoxShape.circle)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF5B9BD5),
          labelColor: const Color(0xFF5B9BD5),
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: '💬 Чаты'), Tab(text: '👥 Люди')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildChatsTab(), _buildPeopleTab()],
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_conversations.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('💬', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('Нет активных чатов', style: TextStyle(color: Colors.grey)),
        SizedBox(height: 4),
        Text('Найдите собеседника во вкладке Люди',
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (_, i) {
          final peer = _conversations[i]['peer'] as String;
          final isOnline = _onlineUsers.contains(peer);
          return _userTile(peer, isOnline, showWriteBtn: false,
            onTap: () => _openChat(peer));
        },
      ),
    );
  }

  Widget _buildPeopleTab() {
    if (_allUsers.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('👥', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('Нет пользователей', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        TextButton(onPressed: _loadPeople, child: const Text('Обновить')),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _loadPeople,
      child: ListView.builder(
        itemCount: _allUsers.length,
        itemBuilder: (_, i) {
          final peer = _allUsers[i];
          final isOnline = _onlineUsers.contains(peer);
          return _userTile(peer, isOnline, showWriteBtn: true,
            onTap: () { _tabController.animateTo(0); _openChat(peer); });
        },
      ),
    );
  }

  Widget _userTile(String peer, bool isOnline, {required bool showWriteBtn, required VoidCallback onTap}) {
    return ListTile(
      leading: Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(backgroundColor: const Color(0xFF2B5278),
          child: Text(peer[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        if (isOnline) Positioned(bottom: 0, right: 0,
          child: Container(width: 10, height: 10,
            decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A2535), width: 2)))),
      ]),
      title: Text(peer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(isOnline ? 'В сети' : 'Не в сети',
        style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
      trailing: showWriteBtn ? ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B5278),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Написать', style: TextStyle(fontSize: 12)),
      ) : null,
      onTap: onTap,
      tileColor: const Color(0xFF1A2535),
    );
  }
}
