import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lan_sync_service_stub.dart'
    if (dart.library.io) 'lan_sync_service_native.dart';

abstract class LanSyncService {
  Future<void> syncNow();
  Future<void> dispose();
}

final lanSyncServiceProvider = Provider<LanSyncService>((ref) {
  final service = createLanSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
