import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/region/regions.dart';

void main() {
  test('every region has a unique two-letter code, a name and at least one zone', () {
    final codes = <String>{};
    for (final region in regions) {
      expect(region.code, matches(RegExp(r'^[A-Z]{2}$')));
      expect(codes.add(region.code), isTrue, reason: 'duplicate code ${region.code}');
      expect(region.name, isNotEmpty);
      expect(region.zones, isNotEmpty);
    }
  });

  test('every zone names both a Windows and a tz-database zone, at a real offset', () {
    for (final region in regions) {
      final ids = <String>{};
      for (final zone in region.zones) {
        expect(zone.windowsId, isNotEmpty, reason: '${region.name}: windows id');
        expect(zone.ianaId, contains('/'), reason: '${region.name}: tz id');
        expect(ids.add(zone.ianaId), isTrue, reason: '${region.name}: duplicate zone ${zone.ianaId}');
        expect(zone.utcOffsetMinutes % 15, 0, reason: '${zone.ianaId}: offsets come in quarter hours');
        expect(zone.utcOffsetMinutes.abs(), lessThanOrEqualTo(14 * 60));
      }
    }
  });

  test('Kenya comes first and is East Africa Time', () {
    final kenya = regions.first;
    expect(kenya.code, 'KE');
    expect(kenya.zones.single.windowsId, 'E. Africa Standard Time');
    expect(kenya.zones.single.utcOffsetMinutes, 180);
    expect(kenya.zones.single.label, 'East Africa Time (UTC+03:00)');
  });

  test('countries on East Africa Time share Kenya\'s Windows zone', () {
    for (final code in ['UG', 'TZ', 'ET', 'SO']) {
      expect(regionByCode(code)!.zones.single.windowsId, 'E. Africa Standard Time', reason: code);
    }
  });

  test('a country with several zones offers each of them', () {
    expect(regionByCode('US')!.zones.map((z) => z.windowsId), [
      'Eastern Standard Time',
      'Central Standard Time',
      'Mountain Standard Time',
      'Pacific Standard Time',
    ]);
  });

  test('lookups return null rather than guessing', () {
    expect(regionByCode('XX'), isNull);
    expect(regionByCode(null), isNull);
    expect(zoneOfRegion(regionByCode('KE')!, 'Europe/Paris'), isNull);
    expect(zoneOfRegion(regionByCode('KE')!, 'Africa/Nairobi'), isNotNull);
  });

  group('matchesOffset', () {
    const nairobi = RegionZone(
      ianaId: 'Africa/Nairobi', windowsId: 'E. Africa Standard Time', name: 'EAT', utcOffsetMinutes: 180,
    );
    const london = RegionZone(
      ianaId: 'Europe/London', windowsId: 'GMT Standard Time', name: 'GMT', utcOffsetMinutes: 0, hasDst: true,
    );

    test('a zone without daylight saving accepts only its own offset', () {
      expect(nairobi.matchesOffset(const Duration(hours: 3)), isTrue);
      expect(nairobi.matchesOffset(const Duration(hours: 4)), isFalse);
      expect(nairobi.matchesOffset(Duration.zero), isFalse);
    });

    test('a zone with daylight saving accepts the standard offset and one hour more', () {
      expect(london.matchesOffset(Duration.zero), isTrue);
      expect(london.matchesOffset(const Duration(hours: 1)), isTrue);
      expect(london.matchesOffset(const Duration(hours: 2)), isFalse);
      expect(london.matchesOffset(const Duration(hours: -1)), isFalse);
    });
  });

  group('suggestRegion (the setup screen\'s first guess)', () {
    test('a device on +03:00 is suggested Kenya, not another East African country', () {
      final suggestion = suggestRegion(const Duration(hours: 3));
      expect(suggestion.region.code, 'KE');
      expect(suggestion.zone.windowsId, 'E. Africa Standard Time');
    });

    test('a device on India time is suggested India', () {
      expect(suggestRegion(const Duration(hours: 5, minutes: 30)).region.code, 'IN');
    });

    test('an offset nothing here uses falls back to Kenya', () {
      expect(suggestRegion(const Duration(hours: 13, minutes: 7)).region.code, 'KE');
    });
  });

  test('formatUtcOffset', () {
    expect(formatUtcOffset(180), 'UTC+03:00');
    expect(formatUtcOffset(0), 'UTC+00:00');
    expect(formatUtcOffset(-300), 'UTC-05:00');
    expect(formatUtcOffset(330), 'UTC+05:30');
  });
}
