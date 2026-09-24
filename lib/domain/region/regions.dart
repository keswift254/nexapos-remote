/// The regions a shop can be in, and the time zone(s) each one uses.
///
/// Curated rather than the whole tz database: a shop owner picks their country
/// from a short list, and the few countries that span several zones (or use
/// daylight saving) offer more than one entry. [windowsId] is the name Windows
/// itself uses for the zone (what `tzutil /s` takes); [ianaId] is the
/// tz-database name (what Android, Linux and macOS use). [utcOffsetMinutes] is
/// the STANDARD offset - a zone with [hasDst] is one hour ahead of it while
/// daylight saving is in force.
class RegionZone {
  const RegionZone({
    required this.ianaId,
    required this.windowsId,
    required this.name,
    required this.utcOffsetMinutes,
    this.hasDst = false,
  });

  final String ianaId;
  final String windowsId;

  /// A name a shop owner recognises ("East Africa Time").
  final String name;
  final int utcOffsetMinutes;
  final bool hasDst;

  /// "East Africa Time (UTC+03:00)".
  String get label => '$name (${formatUtcOffset(utcOffsetMinutes)})';

  /// Whether a device clock currently reading [offset] ahead of UTC is
  /// consistent with this zone: the standard offset, or - for a zone with
  /// daylight saving - one hour more.
  bool matchesOffset(Duration offset) {
    final minutes = offset.inMinutes;
    return minutes == utcOffsetMinutes ||
        (hasDst && minutes == utcOffsetMinutes + 60);
  }
}

class Region {
  const Region(this.code, this.name, this.zones);

  /// ISO 3166 country code.
  final String code;
  final String name;
  final List<RegionZone> zones;
}

String formatUtcOffset(int minutes) {
  final sign = minutes < 0 ? '-' : '+';
  final abs = minutes.abs();
  final hours = (abs ~/ 60).toString().padLeft(2, '0');
  final mins = (abs % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$mins';
}

const _eastAfrica = RegionZone(
  ianaId: 'Africa/Nairobi',
  windowsId: 'E. Africa Standard Time',
  name: 'East Africa Time',
  utcOffsetMinutes: 180,
);
const _centralAfrica = RegionZone(
  ianaId: 'Africa/Maputo',
  windowsId: 'South Africa Standard Time',
  name: 'Central Africa Time',
  utcOffsetMinutes: 120,
);
const _westAfrica = RegionZone(
  ianaId: 'Africa/Lagos',
  windowsId: 'W. Central Africa Standard Time',
  name: 'West Africa Time',
  utcOffsetMinutes: 60,
);
const _greenwich = RegionZone(
  ianaId: 'Africa/Abidjan',
  windowsId: 'Greenwich Standard Time',
  name: 'Greenwich Mean Time',
  utcOffsetMinutes: 0,
);
const _london = RegionZone(
  ianaId: 'Europe/London',
  windowsId: 'GMT Standard Time',
  name: 'Greenwich Mean Time (with daylight saving)',
  utcOffsetMinutes: 0,
  hasDst: true,
);
const _westEurope = RegionZone(
  ianaId: 'Europe/Berlin',
  windowsId: 'W. Europe Standard Time',
  name: 'Central European Time',
  utcOffsetMinutes: 60,
  hasDst: true,
);
const _romance = RegionZone(
  ianaId: 'Europe/Paris',
  windowsId: 'Romance Standard Time',
  name: 'Central European Time',
  utcOffsetMinutes: 60,
  hasDst: true,
);
const _singapore = RegionZone(
  ianaId: 'Asia/Singapore',
  windowsId: 'Singapore Standard Time',
  name: 'Singapore Time',
  utcOffsetMinutes: 480,
);

/// Kenya first: it is where most shops are and what a fresh install suggests.
const List<Region> regions = [
  Region('KE', 'Kenya', [_eastAfrica]),
  Region('UG', 'Uganda', [
    RegionZone(
      ianaId: 'Africa/Kampala',
      windowsId: 'E. Africa Standard Time',
      name: 'East Africa Time',
      utcOffsetMinutes: 180,
    ),
  ]),
  Region('TZ', 'Tanzania', [
    RegionZone(
      ianaId: 'Africa/Dar_es_Salaam',
      windowsId: 'E. Africa Standard Time',
      name: 'East Africa Time',
      utcOffsetMinutes: 180,
    ),
  ]),
  Region('RW', 'Rwanda', [
    RegionZone(
      ianaId: 'Africa/Kigali',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('BI', 'Burundi', [
    RegionZone(
      ianaId: 'Africa/Bujumbura',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('SS', 'South Sudan', [
    RegionZone(
      ianaId: 'Africa/Juba',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('ET', 'Ethiopia', [
    RegionZone(
      ianaId: 'Africa/Addis_Ababa',
      windowsId: 'E. Africa Standard Time',
      name: 'East Africa Time',
      utcOffsetMinutes: 180,
    ),
  ]),
  Region('SO', 'Somalia', [
    RegionZone(
      ianaId: 'Africa/Mogadishu',
      windowsId: 'E. Africa Standard Time',
      name: 'East Africa Time',
      utcOffsetMinutes: 180,
    ),
  ]),
  Region('CD', 'DR Congo', [
    RegionZone(
      ianaId: 'Africa/Kinshasa',
      windowsId: 'W. Central Africa Standard Time',
      name: 'West Africa Time (Kinshasa)',
      utcOffsetMinutes: 60,
    ),
    RegionZone(
      ianaId: 'Africa/Lubumbashi',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time (Lubumbashi)',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('ZM', 'Zambia', [
    RegionZone(
      ianaId: 'Africa/Lusaka',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('ZW', 'Zimbabwe', [
    RegionZone(
      ianaId: 'Africa/Harare',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('MW', 'Malawi', [
    RegionZone(
      ianaId: 'Africa/Blantyre',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('MZ', 'Mozambique', [_centralAfrica]),
  Region('BW', 'Botswana', [
    RegionZone(
      ianaId: 'Africa/Gaborone',
      windowsId: 'South Africa Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('NA', 'Namibia', [
    RegionZone(
      ianaId: 'Africa/Windhoek',
      windowsId: 'Namibia Standard Time',
      name: 'Central Africa Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('ZA', 'South Africa', [
    RegionZone(
      ianaId: 'Africa/Johannesburg',
      windowsId: 'South Africa Standard Time',
      name: 'South Africa Standard Time',
      utcOffsetMinutes: 120,
    ),
  ]),
  Region('NG', 'Nigeria', [_westAfrica]),
  Region('CM', 'Cameroon', [
    RegionZone(
      ianaId: 'Africa/Douala',
      windowsId: 'W. Central Africa Standard Time',
      name: 'West Africa Time',
      utcOffsetMinutes: 60,
    ),
  ]),
  Region('AO', 'Angola', [
    RegionZone(
      ianaId: 'Africa/Luanda',
      windowsId: 'W. Central Africa Standard Time',
      name: 'West Africa Time',
      utcOffsetMinutes: 60,
    ),
  ]),
  Region('GH', 'Ghana', [
    RegionZone(
      ianaId: 'Africa/Accra',
      windowsId: 'Greenwich Standard Time',
      name: 'Greenwich Mean Time',
      utcOffsetMinutes: 0,
    ),
  ]),
  Region('SN', 'Senegal', [
    RegionZone(
      ianaId: 'Africa/Dakar',
      windowsId: 'Greenwich Standard Time',
      name: 'Greenwich Mean Time',
      utcOffsetMinutes: 0,
    ),
  ]),
  Region('CI', "Cote d'Ivoire", [_greenwich]),
  Region('EG', 'Egypt', [
    RegionZone(
      ianaId: 'Africa/Cairo',
      windowsId: 'Egypt Standard Time',
      name: 'Egypt Time',
      utcOffsetMinutes: 120,
      hasDst: true,
    ),
  ]),
  Region('MA', 'Morocco', [
    RegionZone(
      ianaId: 'Africa/Casablanca',
      windowsId: 'Morocco Standard Time',
      name: 'Morocco Time',
      utcOffsetMinutes: 60,
      hasDst: true,
    ),
  ]),
  Region('IN', 'India', [
    RegionZone(
      ianaId: 'Asia/Kolkata',
      windowsId: 'India Standard Time',
      name: 'India Standard Time',
      utcOffsetMinutes: 330,
    ),
  ]),
  Region('PK', 'Pakistan', [
    RegionZone(
      ianaId: 'Asia/Karachi',
      windowsId: 'Pakistan Standard Time',
      name: 'Pakistan Standard Time',
      utcOffsetMinutes: 300,
    ),
  ]),
  Region('BD', 'Bangladesh', [
    RegionZone(
      ianaId: 'Asia/Dhaka',
      windowsId: 'Bangladesh Standard Time',
      name: 'Bangladesh Standard Time',
      utcOffsetMinutes: 360,
    ),
  ]),
  Region('AE', 'United Arab Emirates', [
    RegionZone(
      ianaId: 'Asia/Dubai',
      windowsId: 'Arabian Standard Time',
      name: 'Gulf Standard Time',
      utcOffsetMinutes: 240,
    ),
  ]),
  Region('SA', 'Saudi Arabia', [
    RegionZone(
      ianaId: 'Asia/Riyadh',
      windowsId: 'Arab Standard Time',
      name: 'Arabia Standard Time',
      utcOffsetMinutes: 180,
    ),
  ]),
  Region('TR', 'Turkey', [
    RegionZone(
      ianaId: 'Europe/Istanbul',
      windowsId: 'Turkey Standard Time',
      name: 'Turkey Time',
      utcOffsetMinutes: 180,
    ),
  ]),
  Region('SG', 'Singapore', [_singapore]),
  Region('MY', 'Malaysia', [
    RegionZone(
      ianaId: 'Asia/Kuala_Lumpur',
      windowsId: 'Singapore Standard Time',
      name: 'Malaysia Time',
      utcOffsetMinutes: 480,
    ),
  ]),
  Region('PH', 'Philippines', [
    RegionZone(
      ianaId: 'Asia/Manila',
      windowsId: 'Singapore Standard Time',
      name: 'Philippine Time',
      utcOffsetMinutes: 480,
    ),
  ]),
  Region('ID', 'Indonesia', [
    RegionZone(
      ianaId: 'Asia/Jakarta',
      windowsId: 'SE Asia Standard Time',
      name: 'Western Indonesia Time',
      utcOffsetMinutes: 420,
    ),
  ]),
  Region('CN', 'China', [
    RegionZone(
      ianaId: 'Asia/Shanghai',
      windowsId: 'China Standard Time',
      name: 'China Standard Time',
      utcOffsetMinutes: 480,
    ),
  ]),
  Region('JP', 'Japan', [
    RegionZone(
      ianaId: 'Asia/Tokyo',
      windowsId: 'Tokyo Standard Time',
      name: 'Japan Standard Time',
      utcOffsetMinutes: 540,
    ),
  ]),
  Region('GB', 'United Kingdom', [_london]),
  Region('IE', 'Ireland', [
    RegionZone(
      ianaId: 'Europe/Dublin',
      windowsId: 'GMT Standard Time',
      name: 'Irish Time',
      utcOffsetMinutes: 0,
      hasDst: true,
    ),
  ]),
  Region('DE', 'Germany', [_westEurope]),
  Region('FR', 'France', [_romance]),
  Region('ES', 'Spain', [
    RegionZone(
      ianaId: 'Europe/Madrid',
      windowsId: 'Romance Standard Time',
      name: 'Central European Time',
      utcOffsetMinutes: 60,
      hasDst: true,
    ),
  ]),
  Region('IT', 'Italy', [
    RegionZone(
      ianaId: 'Europe/Rome',
      windowsId: 'W. Europe Standard Time',
      name: 'Central European Time',
      utcOffsetMinutes: 60,
      hasDst: true,
    ),
  ]),
  Region('NL', 'Netherlands', [
    RegionZone(
      ianaId: 'Europe/Amsterdam',
      windowsId: 'W. Europe Standard Time',
      name: 'Central European Time',
      utcOffsetMinutes: 60,
      hasDst: true,
    ),
  ]),
  Region('US', 'United States', [
    RegionZone(
      ianaId: 'America/New_York',
      windowsId: 'Eastern Standard Time',
      name: 'Eastern Time',
      utcOffsetMinutes: -300,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'America/Chicago',
      windowsId: 'Central Standard Time',
      name: 'Central Time',
      utcOffsetMinutes: -360,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'America/Denver',
      windowsId: 'Mountain Standard Time',
      name: 'Mountain Time',
      utcOffsetMinutes: -420,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'America/Los_Angeles',
      windowsId: 'Pacific Standard Time',
      name: 'Pacific Time',
      utcOffsetMinutes: -480,
      hasDst: true,
    ),
  ]),
  Region('CA', 'Canada', [
    RegionZone(
      ianaId: 'America/Toronto',
      windowsId: 'Eastern Standard Time',
      name: 'Eastern Time',
      utcOffsetMinutes: -300,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'America/Winnipeg',
      windowsId: 'Central Standard Time',
      name: 'Central Time',
      utcOffsetMinutes: -360,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'America/Edmonton',
      windowsId: 'Mountain Standard Time',
      name: 'Mountain Time',
      utcOffsetMinutes: -420,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'America/Vancouver',
      windowsId: 'Pacific Standard Time',
      name: 'Pacific Time',
      utcOffsetMinutes: -480,
      hasDst: true,
    ),
  ]),
  Region('BR', 'Brazil', [
    RegionZone(
      ianaId: 'America/Sao_Paulo',
      windowsId: 'E. South America Standard Time',
      name: 'Brasilia Time',
      utcOffsetMinutes: -180,
    ),
  ]),
  Region('AU', 'Australia', [
    RegionZone(
      ianaId: 'Australia/Sydney',
      windowsId: 'AUS Eastern Standard Time',
      name: 'Australian Eastern Time',
      utcOffsetMinutes: 600,
      hasDst: true,
    ),
    RegionZone(
      ianaId: 'Australia/Perth',
      windowsId: 'W. Australia Standard Time',
      name: 'Australian Western Time',
      utcOffsetMinutes: 480,
    ),
  ]),
  Region('NZ', 'New Zealand', [
    RegionZone(
      ianaId: 'Pacific/Auckland',
      windowsId: 'New Zealand Standard Time',
      name: 'New Zealand Time',
      utcOffsetMinutes: 720,
      hasDst: true,
    ),
  ]),
];

/// What a fresh install suggests when nothing better is known.
const defaultRegionCode = 'KE';

Region? regionByCode(String? code) {
  for (final region in regions) {
    if (region.code == code) return region;
  }
  return null;
}

/// The zone of [region] with this tz-database name, or null.
RegionZone? zoneOfRegion(Region region, String? ianaId) {
  for (final zone in region.zones) {
    if (zone.ianaId == ianaId) return zone;
  }
  return null;
}

/// A first guess for the setup screen, from the offset the device itself
/// reports: the first region (in list order, so Kenya wins a tie with the other
/// East African countries) with a zone at that offset. Falls back to Kenya.
({Region region, RegionZone zone}) suggestRegion(Duration deviceOffset) {
  for (final region in regions) {
    for (final zone in region.zones) {
      if (zone.matchesOffset(deviceOffset)) return (region: region, zone: zone);
    }
  }
  final kenya = regionByCode(defaultRegionCode)!;
  return (region: kenya, zone: kenya.zones.first);
}
