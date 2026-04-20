import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pointycastle/export.dart';

class Crypto {
  late Uint8List publicKey;
  late Uint8List secretKey;

  Crypto() {
    final params = ECKeyGeneratorParameters(ECCurve_prime256v1());
    final random = FortunaRandom()
      ..seed(KeyParameter(_randomBytes(32)));
    final gen = ECKeyGenerator()..init(ParametersWithRandom(params, random));
    final pair = gen.generateKeyPair();
    final priv = pair.privateKey as ECPrivateKey;
    final pub  = pair.publicKey as ECPublicKey;
    secretKey = _bigIntToBytes(priv.d!, 32);
    publicKey = pub.Q!.getEncoded(false); // uncompressed
  }

  String exportPublicKey() => base64Encode(publicKey);

  static Uint8List importPublicKey(String b64) => base64Decode(b64);

  Uint8List _deriveShared(Uint8List theirPublicKey) {
    final curve = ECCurve_prime256v1();
    final Q = curve.curve.decodePoint(theirPublicKey)!;
    final d = _bytesToBigInt(secretKey);
    final shared = (Q * d)!;
    final rawSecret = _bigIntToBytes(shared.x!.toBigInteger()!, 32);
    // HKDF-SHA256 to derive proper AES key from raw ECDH output
    return _hkdf(rawSecret, info: utf8.encode('secure_messenger_v1'));
  }

  static Uint8List _hkdf(Uint8List ikm, {required List<int> info, int length = 32}) {
    // HKDF extract: PRK = HMAC-SHA256(salt=zeros, IKM)
    final salt = Uint8List(32);
    final hmacExtract = HMac(SHA256Digest(), 64)..init(KeyParameter(salt));
    hmacExtract.update(ikm, 0, ikm.length);
    final prk = Uint8List(32);
    hmacExtract.doFinal(prk, 0);
    // HKDF expand: T(1) = HMAC-SHA256(PRK, info || 0x01)
    final hmacExpand = HMac(SHA256Digest(), 64)..init(KeyParameter(prk));
    hmacExpand.update(Uint8List.fromList(info), 0, info.length);
    hmacExpand.update(Uint8List.fromList([0x01]), 0, 1);
    final okm = Uint8List(32);
    hmacExpand.doFinal(okm, 0);
    return okm.sublist(0, length);
  }

  String encrypt(String text, Uint8List theirPublicKey) {
    final sharedKey = _deriveShared(theirPublicKey);
    final iv  = _randomBytes(12);
    final key = KeyParameter(sharedKey);
    final params = AEADParameters(key, 128, iv, Uint8List(0));
    final cipher = GCMBlockCipher(AESEngine())..init(true, params);
    final input = Uint8List.fromList(utf8.encode(text));
    final ct = cipher.process(input);
    final out = Uint8List(iv.length + ct.length);
    out.setAll(0, iv);
    out.setAll(iv.length, ct);
    return base64Encode(out);
  }

  String decrypt(String b64, Uint8List theirPublicKey) {
    final sharedKey = _deriveShared(theirPublicKey);
    final data = base64Decode(b64);
    final iv = data.sublist(0, 12);
    final ct = data.sublist(12);
    final key = KeyParameter(sharedKey);
    final params = AEADParameters(key, 128, iv, Uint8List(0));
    final cipher = GCMBlockCipher(AESEngine())..init(false, params);
    final pt = cipher.process(ct);
    return utf8.decode(pt);
  }

  static Uint8List _randomBytes(int len) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(len, (_) => rng.nextInt(256)));
  }

  static Uint8List _bigIntToBytes(BigInt n, int len) {
    final hex = n.toRadixString(16).padLeft(len * 2, '0');
    return Uint8List.fromList(List.generate(len, (i) => int.parse(hex.substring(i*2, i*2+2), radix: 16)));
  }

  static BigInt _bytesToBigInt(Uint8List bytes) =>
    bytes.fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));
}
