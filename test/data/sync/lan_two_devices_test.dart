import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/services/lan_sync_service.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

/// Two complete tills - each with its own database and the real LAN service -
/// talking over REAL sockets on this machine (UDP broadcast announcements, TCP
/// pulls), so the time it takes a change to travel from one to the other is
/// measured, not guessed.
///
/// The shop id and key are made up for the test, so nothing here can be mistaken
/// for a real shop's traffic (a NexaPOS running on the same PC hears the packets
/// and drops them: wrong shop).

class _MemoryStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(values[invocation.namedArguments[#key]]);
      case #write:
        values[invocation.namedArguments[#key] as String] =
            invocation.namedArguments[#value] as String;
        return Future<void>.value();
      case #delete:
        values.remove(invocation.namedArguments[#key]);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _NoLease extends Fake implements LicenseService {
  @override
  Future<LeaseOffer?> leaseToShare() async => null;
}

class _Credentials implements PaystackCredentialsService {
  _Credentials({this.configured = false});
  final bool configured;

  @override
  Future<PaystackCredentials> load() async => PaystackCredentials(
    baseUrl: configured ? 'http://cloud.invalid/index.php' : '',
    apiKey: configured ? 'k' : '',
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

class _Till {
  _Till._(this.name, this.db, this.meta, this.sync, this.container, this.deviceId);

  final String name;
  final AppDatabase db;
  final SyncMetadataService meta;
  final SyncService sync;
  final ProviderContainer container;
  final String deviceId;
  Timer? _heartbeat;

  static Future<_Till> create(
    String name, {
    required int shopId,
    required List<int> key,
    http.Client? cloud,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final meta = SyncMetadataService(db);
    final deviceId = await meta.deviceId();
    final sync = SyncService(
      db,
      meta,
      PlatformSyncGateway(
        cloud ?? MockClient((_) async => throw StateError('no internet')),
      ),
      _Credentials(configured: cloud != null),
    );
    final storage = _MemoryStorage()
      ..values['nexapos.lanSync.credentials.v1'] = jsonEncode({
        'shopId': shopId,
        'deviceId': deviceId,
        'secret': base64Encode(key),
      });
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStorageProvider.overrideWithValue(storage),
        syncServiceProvider.overrideWithValue(sync),
        licenseServiceProvider.overrideWithValue(_NoLease()),
        paystackCredentialsServiceProvider.overrideWithValue(_Credentials()),
      ],
    );
    return _Till._(name, db, meta, sync, container, deviceId);
  }

  LanSyncService get lan => container.read(lanSyncServiceProvider);

  /// What app.dart does: an announcement now, then one every 2 seconds.
  Future<void> startLan() async {
    await lan.syncNow();
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) => lan.syncNow());
  }

  Future<void> addCategory(String id) => CategoryRepositoryImpl(
    db,
    db.categoriesDao,
    meta,
    const SystemClock(),
    UuidIdGenerator(),
  ).create(Category(id: id, name: 'Made on $name', status: 'active'));

  Future<bool> has(String id) async =>
      (await db.select(db.categories).get()).any((c) => c.id == id);

  Future<void> close() async {
    _heartbeat?.cancel();
    container.dispose();
    await db.close();
  }
}

/// How long until [till] holds [id], or null if it never does within [within].
Future<Duration?> _arrival(
  _Till till,
  String id, {
  Duration within = const Duration(seconds: 40),
}) async {
  final clock = Stopwatch()..start();
  while (clock.elapsed < within) {
    if (await till.has(id)) return clock.elapsed;
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
  return null;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final random = Random.secure();
  final key = List<int>.generate(32, (_) => random.nextInt(256));
  final shopId = 900000000 + random.nextInt(99999999);

  late _Till a;
  late _Till b;

  Future<void> bothOnline({http.Client? cloudForB}) async {
    a = await _Till.create('A', shopId: shopId, key: key);
    b = await _Till.create('B', shopId: shopId, key: key, cloud: cloudForB);
    await a.startLan();
    await b.startLan();
    // Give the sockets a moment to come up, as a running till has long since done.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('a change on one till reaches the other, and how fast', () async {
    await bothOnline();
    final made = Stopwatch()..start();
    await a.addCategory('from-a-1');
    final took = await _arrival(b, 'from-a-1');
    // ignore: avoid_print
    print('A -> B: ${took?.inMilliseconds} ms (write took ${made.elapsedMilliseconds} ms incl. wait)');
    expect(took, isNotNull, reason: 'the change never arrived over the LAN');
    expect(took!, lessThan(const Duration(seconds: 3)));
  });

  test('both tills change at once: each gets the other\'s, and how fast', () async {
    await bothOnline();
    await Future.wait([a.addCategory('both-a'), b.addCategory('both-b')]);
    final results = await Future.wait([_arrival(b, 'both-a'), _arrival(a, 'both-b')]);
    // ignore: avoid_print
    print('simultaneous: A->B ${results[0]?.inMilliseconds} ms, B->A ${results[1]?.inMilliseconds} ms');
    expect(results[0], isNotNull);
    expect(results[1], isNotNull);
    expect(results[0]!, lessThan(const Duration(seconds: 3)));
    expect(results[1]!, lessThan(const Duration(seconds: 3)));
  });

  test('a burst of sales on one till, then one on the other, each lands quickly', () async {
    await bothOnline();
    for (var i = 0; i < 5; i++) {
      final id = 'burst-$i';
      await a.addCategory(id);
      final took = await _arrival(b, id);
      // ignore: avoid_print
      print('burst $i: ${took?.inMilliseconds} ms');
      expect(took, isNotNull, reason: 'change $i never arrived');
      expect(took!, lessThan(const Duration(seconds: 3)));
    }
    await b.addCategory('reply-from-b');
    final back = await _arrival(a, 'reply-from-b');
    // ignore: avoid_print
    print('B -> A after the burst: ${back?.inMilliseconds} ms');
    expect(back, isNotNull);
    expect(back!, lessThan(const Duration(seconds: 3)));
  });

  test('while B is stuck waiting on a dead internet request, A\'s change still lands quickly', () async {
    final neverAnswers = Completer<http.Response>();
    addTearDown(() {
      if (!neverAnswers.isCompleted) neverAnswers.completeError(StateError('done'));
    });
    await bothOnline(cloudForB: MockClient((_) => neverAnswers.future));
    // B's cloud cycle starts and hangs on its first request.
    unawaited(b.sync.runSyncCycle().catchError((Object _) {}));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await a.addCategory('while-cloud-hangs');
    final took = await _arrival(b, 'while-cloud-hangs');
    // ignore: avoid_print
    print('A -> B with B waiting on the cloud: ${took?.inMilliseconds} ms');
    expect(took, isNotNull);
    expect(took!, lessThan(const Duration(seconds: 3)));
  });
}
