import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/core/secure_storage_provider.dart';
import 'package:nexapos_mobile/domain/region/regions.dart';
import 'package:nexapos_mobile/domain/services/region_settings_service.dart';

import '../../support/fake_secure_storage.dart';

const _key = 'nexapos.region.v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    installFakeSecureStorage();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  RegionSettings uganda() {
    final region = regionByCode('UG')!;
    return RegionSettings(region: region, zone: region.zones.single);
  }

  test('nothing is chosen on an install that predates the setting', () async {
    expect(await container.read(regionSettingsServiceProvider).load(), isNull);
    expect(await container.read(regionSettingsProvider.future), isNull);
  });

  test('a saved region and zone read back the same', () async {
    await container.read(regionSettingsServiceProvider).save(uganda());

    final loaded = await container.read(regionSettingsServiceProvider).load();

    expect(loaded!.region.code, 'UG');
    expect(loaded.zone.ianaId, 'Africa/Kampala');
    expect(loaded.zone.windowsId, 'E. Africa Standard Time');
  });

  test('saving refreshes what the provider shows', () async {
    expect(await container.read(regionSettingsProvider.future), isNull);

    await container.read(regionSettingsProvider.notifier).save(uganda());

    expect((await container.read(regionSettingsProvider.future))!.region.code, 'UG');
    expect((await container.read(regionSettingsServiceProvider).load())!.region.code, 'UG', reason: 'and it is stored');
  });

  test('a later choice replaces the earlier one', () async {
    final service = container.read(regionSettingsServiceProvider);
    await service.save(uganda());
    final us = regionByCode('US')!;

    await service.save(RegionSettings(region: us, zone: us.zones[1]));

    final loaded = (await service.load())!;
    expect(loaded.region.code, 'US');
    expect(loaded.zone.windowsId, 'Central Standard Time');
  });

  test('corrupt or unknown saved values are ignored, not a crash', () async {
    final storage = container.read(secureStorageProvider);
    final service = container.read(regionSettingsServiceProvider);

    await storage.write(key: _key, value: '{not json');
    expect(await service.load(), isNull);

    await storage.write(key: _key, value: '{"country":"XX","zone":"Nowhere/Land"}');
    expect(await service.load(), isNull, reason: 'a country this build does not know');

    await storage.write(key: _key, value: '{"country":"KE","zone":"Europe/Paris"}');
    expect(await service.load(), isNull, reason: 'a zone that is not one of that country\'s');

    await storage.write(key: _key, value: '[1,2,3]');
    expect(await service.load(), isNull);
  });
}
