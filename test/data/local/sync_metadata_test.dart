import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/data/local/sync_metadata.dart';

void main() {
  late AppDatabase db;
  late SyncMetadataService syncMeta;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    syncMeta = SyncMetadataService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('push/pull cursors default to 0', () async {
    expect(await syncMeta.lastPushedLocalRev(), 0);
    expect(await syncMeta.lastPulledChangeId(), 0);
  });

  test('setLastPushedLocalRev/setLastPulledChangeId persist and read back', () async {
    await syncMeta.setLastPushedLocalRev(42);
    await syncMeta.setLastPulledChangeId(7);
    expect(await syncMeta.lastPushedLocalRev(), 42);
    expect(await syncMeta.lastPulledChangeId(), 7);
  });

  test('resetCursors zeroes both cursors', () async {
    await syncMeta.setLastPushedLocalRev(42);
    await syncMeta.setLastPulledChangeId(7);
    await syncMeta.resetCursors();
    expect(await syncMeta.lastPushedLocalRev(), 0);
    expect(await syncMeta.lastPulledChangeId(), 0);
  });

  test('nextLocalRev is unaffected by the sync cursors', () async {
    final before = await syncMeta.nextLocalRev();
    await syncMeta.setLastPushedLocalRev(999);
    final after = await syncMeta.nextLocalRev();
    expect(after, before + 1);
  });

  test(
    'registrationSecret is generated once at seed time, non-empty, and distinct from deviceId - '
    'sent to nexapos_platform as proof-of-possession for the registration grace window, so it '
    'must actually be a real secret, not blank or a duplicate of a value that is not secret at all',
    () async {
      final deviceId = await syncMeta.deviceId();
      final secret = await syncMeta.registrationSecret();

      expect(secret, isNotEmpty);
      expect(secret, isNot(equals(deviceId)));
    },
  );

  test('registrationSecret is stable across repeated reads, not regenerated per call', () async {
    final first = await syncMeta.registrationSecret();
    final second = await syncMeta.registrationSecret();
    expect(first, second);
  });
}
