import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/secure_storage_provider.dart';
import '../region/regions.dart';

const _regionKey = 'nexapos.region.v1';

/// The region and time zone this shop's device is in, as the owner chose them
/// (at setup, or later under Settings > Region and Time). What the clock check
/// compares the device's own time zone against. Not a secret - kept in the same
/// secure storage as the app's other small per-device settings only because
/// that is where they live.
class RegionSettings {
  const RegionSettings({required this.region, required this.zone});

  final Region region;
  final RegionZone zone;

  Map<String, dynamic> toJson() => {
    'country': region.code,
    'zone': zone.ianaId,
  };

  /// Null for anything that is not a region and zone this build knows about (a
  /// corrupt value, or one written by a newer build with a longer list).
  static RegionSettings? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final region = regionByCode(decoded['country'] as String?);
    if (region == null) return null;
    final zone = zoneOfRegion(region, decoded['zone'] as String?);
    if (zone == null) return null;
    return RegionSettings(region: region, zone: zone);
  }
}

class RegionSettingsService {
  RegionSettingsService(this._ref);

  final Ref _ref;

  Future<RegionSettings?> load() async {
    final raw = await _ref.read(secureStorageProvider).read(key: _regionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RegionSettings.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RegionSettings settings) async {
    await _ref
        .read(secureStorageProvider)
        .write(key: _regionKey, value: jsonEncode(settings.toJson()));
  }
}

final regionSettingsServiceProvider = Provider<RegionSettingsService>(
  (ref) => RegionSettingsService(ref),
);

/// The saved region, or null when none has been chosen yet (every install that
/// predates the setting). Screens that show or change it use this; the clock
/// check reads the storage itself each time it runs.
class RegionSettingsNotifier extends AsyncNotifier<RegionSettings?> {
  @override
  Future<RegionSettings?> build() =>
      ref.read(regionSettingsServiceProvider).load();

  Future<void> save(RegionSettings settings) async {
    await ref.read(regionSettingsServiceProvider).save(settings);
    state = AsyncData(settings);
  }
}

final regionSettingsProvider =
    AsyncNotifierProvider<RegionSettingsNotifier, RegionSettings?>(
      RegionSettingsNotifier.new,
    );
