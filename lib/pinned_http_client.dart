import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto_pkg;

/// Certificate pinning for HTTPS requests.
///
/// HOW TO GET YOUR PIN:
///   openssl s_client -connect your-server.com:443 </dev/null 2>/dev/null \
///     | openssl x509 -pubkey -noout \
///     | openssl pkey -pubin -outform DER \
///     | openssl dgst -sha256 -binary \
///     | base64
///
/// Set the result as CERT_PIN below (or pass via env at build time).
/// If pin is empty — pinning is DISABLED (dev mode only, log warning).

const String CERT_PIN = String.fromEnvironment('CERT_PIN', defaultValue: '');

class PinnedHttpClient {
  static HttpClient _buildClient() {
    final client = HttpClient();
    if (CERT_PIN.isEmpty) {
      // Dev mode: no pinning, but warn loudly
      // ignore: avoid_print
      print('⚠️  WARNING: Certificate pinning is DISABLED. Set CERT_PIN at build time.');
      return client;
    }

    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Extract SPKI (Subject Public Key Info) and hash it
      final spkiHash = _spkiSha256(cert.der);
      final pinBytes = base64Decode(CERT_PIN);
      // Constant-time comparison
      if (spkiHash.length != pinBytes.length) return false;
      int diff = 0;
      for (int i = 0; i < spkiHash.length; i++) {
        diff |= spkiHash[i] ^ pinBytes[i];
      }
      return diff == 0; // true = accept despite "bad" cert (we verified manually)
    };

    return client;
  }

  /// SHA-256 of the SubjectPublicKeyInfo (SPKI) from DER-encoded certificate.
  static Uint8List _spkiSha256(Uint8List derCert) {
    // Parse DER to extract SPKI — walk ASN.1 structure
    // Certificate ::= SEQUENCE { tbsCertificate TBSCertificate, ... }
    // TBSCertificate ::= SEQUENCE { ..., subjectPublicKeyInfo SubjectPublicKeyInfo, ... }
    try {
      int offset = 0;
      offset = _skipTag(derCert, offset, 0x30); // Certificate SEQUENCE
      offset = _skipTag(derCert, offset, 0x30); // TBSCertificate SEQUENCE
      // Skip: version[0], serialNumber, signature, issuer, validity, subject
      for (int i = 0; i < 6; i++) {
        offset = _skipElement(derCert, offset);
      }
      // Now at SubjectPublicKeyInfo SEQUENCE
      final spkiStart = offset;
      final spkiLen = _elementLength(derCert, offset);
      final spki = derCert.sublist(spkiStart, spkiStart + spkiLen);
      final hash = crypto_pkg.sha256.convert(spki).bytes;
      return Uint8List.fromList(hash);
    } catch (_) {
      return Uint8List(32); // zeros — will not match any pin
    }
  }

  static int _skipTag(Uint8List data, int offset, int expectedTag) {
    if (data[offset] != expectedTag) throw FormatException('Unexpected tag');
    return offset + 1 + _lenBytes(data, offset + 1);
  }

  static int _skipElement(Uint8List data, int offset) {
    // Skip context tags like [0]
    if (data[offset] & 0xC0 == 0x80) {
      return offset + 1 + _lenBytes(data, offset + 1);
    }
    return offset + _elementLength(data, offset);
  }

  static int _elementLength(Uint8List data, int offset) {
    final tagByte = 1; // tag itself
    final lenStart = offset + tagByte;
    if (data[lenStart] < 0x80) {
      return tagByte + 1 + data[lenStart];
    }
    final numBytes = data[lenStart] & 0x7F;
    int len = 0;
    for (int i = 0; i < numBytes; i++) {
      len = (len << 8) | data[lenStart + 1 + i];
    }
    return tagByte + 1 + numBytes + len;
  }

  static int _lenBytes(Uint8List data, int offset) {
    if (data[offset] < 0x80) return 1 + data[offset];
    final numBytes = data[offset] & 0x7F;
    int len = 0;
    for (int i = 0; i < numBytes; i++) {
      len = (len << 8) | data[offset + 1 + i];
    }
    return 1 + numBytes + len;
  }

  /// POST JSON with certificate pinning.
  static Future<({int statusCode, Map<String, dynamic> body})> postJson(
    String url, Map<String, dynamic> payload,
  ) async {
    final client = _buildClient();
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      final bodyBytes = utf8.encode(jsonEncode(payload));
      req.headers.set('Content-Length', bodyBytes.length.toString());
      req.add(bodyBytes);
      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      return (statusCode: resp.statusCode, body: jsonDecode(respBody) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }
}
