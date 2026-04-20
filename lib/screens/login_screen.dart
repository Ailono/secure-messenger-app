import 'package:flutter/material.dart';
import '../pinned_http_client.dart';
import 'users_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverCtrl = TextEditingController(text: 'secure-messenger-8od2.onrender.com');
  final _userCtrl   = TextEditingController();
  final _passCtrl   = TextEditingController();
  String _error = '';
  bool _loading = false;

  Future<void> _auth(bool isRegister) async {
    final server = _serverCtrl.text.trim();
    final user   = _userCtrl.text.trim();
    final pass   = _passCtrl.text;
    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Заполните все поля'); return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'Пароль минимум 8 символов'); return;
    }
    setState(() { _loading = true; _error = ''; });

    try {
      final endpoint = isRegister ? 'register' : 'login';
      final url = 'https://$server/$endpoint';
      final result = await PinnedHttpClient.postJson(
        url, {'username': user, 'password': pass},
      );
      if (result.statusCode != 200) {
        setState(() => _error = result.body['error'] ?? 'Ошибка');
        return;
      }
      final token = result.body['token'] as String;
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => UsersScreen(server: server, username: user, token: token),
      ));
    } catch (e) {
      setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔒', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            const Text('Secure Messenger', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5B9BD5))),
            const SizedBox(height: 32),
            _field(_serverCtrl, 'Адрес сервера'),
            const SizedBox(height: 12),
            _field(_userCtrl, 'Имя пользователя'),
            const SizedBox(height: 12),
            _field(_passCtrl, 'Пароль', obscure: true),
            const SizedBox(height: 8),
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator(color: Color(0xFF5B9BD5))
            else ...[
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => _auth(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5278),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Войти', style: TextStyle(fontSize: 16)),
              )),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => _auth(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B9BD5),
                  side: const BorderSide(color: Color(0xFF2B5278)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Регистрация', style: TextStyle(fontSize: 16)),
              )),
            ],
            const SizedBox(height: 12),
            const Text('Пароль хранится только в виде bcrypt-хэша',
              style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {bool obscure = false}) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Colors.grey),
        filled: true, fillColor: const Color(0xFF1E2D3D),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A50))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A50))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF5B9BD5))),
      ),
    );
}
