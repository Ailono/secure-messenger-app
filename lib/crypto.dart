import 'dart:typed_data';
import 'dart:convert';
import 'package:pinenacl/x25519.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crypto — X25519 + XSalsa20-Poly1305 (NaCl box)
/// 100% compatible with TweetNaCl used in the web client.
/// Key pair is persisted in SharedPreferences so history survives restarts.

class Crypto {
  late PrivateKey _privateKey;
  late Uint8List publicKey;

  void Function(String newPubKeyB64)? onRatchet;

  static Future<Crypto> init(String username) async {
    final c = Crypto._();
    await c._loadOrGenerate(username);
    return c;
  }

  Crypto._();

  Future<void> _loadOrGenerate(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'keypair_$username';
    final saved = prefs.getString(storageKey);

    if (saved != null) {
      try {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        _privateKey = PrivateKey(Uint8List.fromList(base64Decode(map['sec'] as String)));
        publicKey   = Uint8List.fromList(base64Decode(map['pub'] as String));
        return;
      } catch (_) {}
    }

    _privateKey = PrivateKey.generate();
    publicKey   = Uint8List.fromList(_privateKey.publicKey.asTypedList);
    await prefs.setString(storageKey, jsonEncode({
      'sec': base64Encode(_privateKey.asTypedList),
      'pub': base64Encode(publicKey),
    }));
  }

  String exportPublicKey() => base64Encode(publicKey);

  // ── NaCl box: nonce(24) + ciphertext ──────────────────────────────────────

  String encrypt(String text, Uint8List theirPublicKey) {
    final box = Box(
      myPrivateKey: _privateKey,
      theirPublicKey: PublicKey(theirPublicKey),
    );
    final encrypted = box.encrypt(Uint8List.fromList(utf8.encode(text)));
    final out = Uint8List(24 + encrypted.cipherText.length);
    out.setAll(0, encrypted.nonce.asTypedList);
    out.setAll(24, encrypted.cipherText.asTypedList);
    return base64Encode(out);
  }

  String decrypt(String b64, Uint8List theirPublicKey) {
    final box = Box(
      myPrivateKey: _privateKey,
      theirPublicKey: PublicKey(theirPublicKey),
    );
    final data       = base64Decode(b64);
    final nonce      = Uint8List.fromList(data.sublist(0, 24));
    final cipherText = Uint8List.fromList(data.sublist(24));
    final plain      = box.decrypt(EncryptedMessage(nonce: nonce, cipherText: cipherText));
    return utf8.decode(plain);
  }
}
