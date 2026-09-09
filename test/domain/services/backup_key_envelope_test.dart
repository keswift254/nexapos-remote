import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/google_drive_backup_service.dart';

void main() {
  final rawKey = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('unwrap recovers the exact original key with the right passphrase', () async {
    final envelope = await BackupKeyEnvelope.wrap(rawKey, 'correct horse battery staple');
    final recovered = await BackupKeyEnvelope.unwrap(envelope, 'correct horse battery staple');
    expect(recovered, rawKey);
  });

  test('unwrap rejects the wrong passphrase', () async {
    final envelope = await BackupKeyEnvelope.wrap(rawKey, 'correct horse battery staple');
    await expectLater(
      BackupKeyEnvelope.unwrap(envelope, 'wrong passphrase'),
      throwsA(isA<StateError>()),
    );
  });

  test('unwrap rejects a tampered envelope', () async {
    final envelope = await BackupKeyEnvelope.wrap(rawKey, 'correct horse battery staple');
    final json = jsonDecode(utf8.decode(envelope)) as Map<String, dynamic>;
    final tamperedData = base64Decode(json['data'] as String);
    tamperedData[0] ^= 0xFF;
    json['data'] = base64Encode(tamperedData);
    final tampered = Uint8List.fromList(utf8.encode(jsonEncode(json)));

    await expectLater(
      BackupKeyEnvelope.unwrap(tampered, 'correct horse battery staple'),
      throwsA(isA<StateError>()),
    );
  });

  test('unwrap rejects a non-envelope payload', () async {
    final notAnEnvelope = Uint8List.fromList(utf8.encode(jsonEncode({'format': 'something-else', 'version': 1})));
    await expectLater(
      BackupKeyEnvelope.unwrap(notAnEnvelope, 'correct horse battery staple'),
      throwsA(isA<FormatException>()),
    );
  });

  test('two wraps of the same key produce different ciphertext (fresh salt/nonce each time)', () async {
    final first = await BackupKeyEnvelope.wrap(rawKey, 'correct horse battery staple');
    final second = await BackupKeyEnvelope.wrap(rawKey, 'correct horse battery staple');
    expect(first, isNot(equals(second)));
  });
}
