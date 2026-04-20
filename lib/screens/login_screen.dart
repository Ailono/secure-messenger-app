import 'package:flutter/material.dart';
import 'chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverCtrl = TextEditingController(text: 'secure-messenger-8od2.onrender.com');
  final _userCtrl   = TextEditingController();
  final _peerCtrl   = TextEditingController();
  String _error = '';

  void _connect() {
    final server = _serverCtrl.text.trim();
    final user   = _userCtrl.text.trim();
    final peer   = _peerCtrl.text.trim();

    if (server.isEmpty || user.isEmpty || peer.isEmpty) {
      setState(() => _error = 'Заполните все поля');
      return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ChatScreen(server: server, username: user, peer: peer),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💬', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text('Secure Messenger',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5B9BD5))),
              const SizedBox(height: 32),
              _field(_serverCtrl, 'Адрес сервера'),
              const SizedBox(height: 12),
              _field(_userCtrl, 'Ваше имя'),
              const SizedBox(height: 12),
              _field(_peerCtrl, 'Имя собеседника'),
              const SizedBox(height: 8),
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B5278),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Подключиться', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E2D3D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A50)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A50)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF5B9BD5)),
        ),
      ),
    );
  }
}
