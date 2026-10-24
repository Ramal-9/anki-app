import 'dart:convert';

import 'package:anki_flow/services/sync_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync payload round-trips through AES-GCM and rejects a wrong password', () async {
    final salt = base64Encode(List<int>.generate(16, (i) => i));
    final key = await SyncCrypto.deriveKey('correct horse', base64Decode(salt));
    final env = await SyncCrypto.encrypt(key, salt, '{"decks":[]}');
    expect(env['ct'], isNot(contains('decks')));
    expect(await SyncCrypto.decrypt(key, env), '{"decks":[]}');

    final wrong = await SyncCrypto.deriveKey('wrong horse', base64Decode(salt));
    expect(() => SyncCrypto.decrypt(wrong, env), throwsA(anything));
  });
}
