import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/local/database.dart';
import '../data/local/sync_metadata.dart';
import 'utils/clock.dart';
import 'utils/id_generator.dart';

part 'providers.g.dart';

/// One AppDatabase instance for the app's lifetime. keepAlive: true
/// since closing/reopening the database mid-session would drop the
/// Drift stream subscriptions every screen depends on.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
SyncMetadataService syncMetadata(Ref ref) {
  return SyncMetadataService(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => UuidIdGenerator();

@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage();
