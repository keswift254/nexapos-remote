import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lan_sync_service_stub.dart'
    if (dart.library.io) 'lan_sync_service_native.dart';

abstract class LanSyncService {
  Future<void> syncNow();

  /// Replaces any cached shop LAN key with the credentials the platform
  /// currently assigns to this device. Call immediately after joining or
  /// switching shops: register_device initially places a new device in a
  /// temporary shop, so retaining that shop's key would make cloud sync work
  /// while every encrypted packet from the newly joined shop is rejected.
  Future<void> refreshCredentials();

  Future<void> dispose();
}

final lanSyncServiceProvider = Provider<LanSyncService>((ref) {
  final service = createLanSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
