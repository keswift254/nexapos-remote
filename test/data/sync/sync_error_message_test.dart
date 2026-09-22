import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

/// The sync screen used to say "Offline" for EVERY failure to get an answer,
/// including a server that was reachable but slow (a waking-up free-tier
/// server, or a big shop's first download). People with working internet were
/// told to fix their connection. These pin the two cases apart.
class _Credentials implements PaystackCredentialsService {
  @override
  Future<PaystackCredentials> load() async => const PaystackCredentials(
    baseUrl: 'https://example.com/index.php',
    apiKey: 'device-key',
    currency: 'KES',
    defaultEmail: '',
  );
  @override
  Future<void> save(PaystackCredentials value) async {}
  @override
  Future<String> loadDeviceLabel() async => '';
  @override
  Future<void> saveDeviceLabel(String label) async {}
  @override
  Future<void> clearRegistration() async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  SyncService serviceWhere(Future<http.Response> Function(http.Request) handler) => SyncService(
    db,
    SyncMetadataService(db),
    PlatformSyncGateway(MockClient(handler)),
    _Credentials(),
  );

  test('a request that times out is reported as a slow server, not as being offline', () async {
    final sync = serviceWhere((_) async => throw TimeoutException('no answer in time'));

    await sync.runSyncCycle();

    expect(sync.lastError, contains('slow to answer'));
    expect(sync.lastError, isNot(contains('Offline')));
  });

  test('no connection at all is still reported as offline', () async {
    final sync = serviceWhere((_) async => throw const SocketException('Failed host lookup'));

    await sync.runSyncCycle();

    expect(sync.lastError, startsWith('Offline'));
  });

  test('the exception itself says which case it is', () {
    expect(const PaystackOfflineException().timedOut, isFalse);
    expect(const PaystackOfflineException(timedOut: true).timedOut, isTrue);
  });
}
