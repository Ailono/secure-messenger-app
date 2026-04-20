import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const SecureMessengerApp());
}

class SecureMessengerApp extends StatelessWidget {
  const SecureMessengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Messenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5B9BD5),
          surface: Color(0xFF1E2D3D),
        ),
        scaffoldBackgroundColor: const Color(0xFF16212E),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}
