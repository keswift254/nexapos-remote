import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage_provider.g.dart';

/// Split out of providers.dart so that files needing only the plain,
/// platform-agnostic providers there (appDatabase, syncMetadata, clock,
/// idGenerator - all of which compile for web) don't transitively pull
/// in flutter_secure_storage, which is Flutter-only (imports the real
/// Flutter framework, not just a plugin interface). This was blocking
/// the drift-web spike test from running via plain `dart test`, since
/// every repository imported providers.dart just for appDatabaseProvider
/// and got flutter_secure_storage along for the ride.
@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) => const FlutterSecureStorage();
