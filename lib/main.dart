import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background push received — Flutter handles notification display automatically
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {
    // Firebase not configured yet — app works without push notifications
  }
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
