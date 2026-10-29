import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// End-to-end encryption of the sync payload: AES-256-GCM with a key derived
/// from the sync password by PBKDF2-SHA256. In browsers this runs on WebCrypto.
class SyncCrypto {
  static const _iterations = 210000;
  static final _aes = AesGcm.with256bits();

  static Future<List<int>> deriveKey(String password, List<int> salt) async {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256);
    final key = await kdf.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }

  static Future<Map<String, dynamic>> encrypt(List<int> key, String salt, String plain) async {
    final box = await _aes.encrypt(utf8.encode(plain), secretKey: SecretKey(key));
    return {
      'app': 'anki-flow',
      'v': 1,
      'kdf': 'pbkdf2-sha256',
      'iter': _iterations,
      'salt': salt,
      'nonce': base64Encode(box.nonce),
      'ct': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
      'updated': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Future<String> decrypt(List<int> key, Map<String, dynamic> env) async {
    final box = SecretBox(base64Decode(env['ct']), nonce: base64Decode(env['nonce']), mac: Mac(base64Decode(env['mac'])));
    final plain = await _aes.decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(plain);
  }

  static List<int> randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

}
