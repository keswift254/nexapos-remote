import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lan_sync_service.dart';

LanSyncService createLanSyncService(Ref ref) => _NoLanSyncService();

class _NoLanSyncService implements LanSyncService {
  @override
  Future<void> syncNow() async {}

  @override
  Future<void> dispose() async {}
}
