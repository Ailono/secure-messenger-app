import 'dart:typed_data';
import 'dart:convert';
import 'package:tweetnacl/tweetnacl.dart';

class Crypto {
  late Uint8List publicKey;
  late Uint8List secretKey;

  Crypto() {
    final kp = Box.keyPair();
    publicKey = kp.publicKey;
    secretKey = kp.secretKey;
  }

  String exportPublicKey() => base64Encode(publicKey);

  static Uint8List importPublicKey(String b64) => base64Decode(b64);

  String encrypt(String text, Uint8List theirPublicKey) {
    final nonce = TweetNaClExt.randombytes(Box.nonceLength);
    final box = Box(theirPublicKey, secretKey);
    final msg = Uint8List.fromList(utf8.encode(text));
    final ct = box.box(null, msg, nonce)!;
    final out = Uint8List(nonce.length + ct.length);
    out.setAll(0, nonce);
    out.setAll(nonce.length, ct);
    return base64Encode(out);
  }

  String decrypt(String b64, Uint8List theirPublicKey) {
    final data = base64Decode(b64);
    final nonce = data.sublist(0, Box.nonceLength);
    final ct = data.sublist(Box.nonceLength);
    final box = Box(theirPublicKey, secretKey);
    final pt = box.open(null, ct, nonce)!;
    return utf8.decode(pt);
  }
}
