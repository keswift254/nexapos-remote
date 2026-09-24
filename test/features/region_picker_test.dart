import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/domain/region/regions.dart';
import 'package:nexapos_mobile/domain/services/region_settings_service.dart';
import 'package:nexapos_mobile/features/region/region_picker.dart';

RegionSettings _choice(String code, {int zone = 0}) {
  final region = regionByCode(code)!;
  return RegionSettings(region: region, zone: region.zones[zone]);
}

void main() {
  late RegionSettings selected;
  RegionSettings? lastChange;

  Future<void> show(WidgetTester tester, RegionSettings initial) async {
    selected = initial;
    lastChange = null;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: RegionPicker(
              selected: selected,
              onChanged: (value) {
                lastChange = value;
                setState(() => selected = value);
              },
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('shows the chosen country, and a country with one zone shows it as plain text', (tester) async {
    await show(tester, _choice('KE'));

    expect(find.text('Kenya'), findsOneWidget);
    expect(find.byKey(const Key('region-zone-fixed')), findsOneWidget);
    expect(find.text('East Africa Time (UTC+03:00)'), findsOneWidget);
    expect(find.byKey(const Key('region-zone')), findsNothing);
  });

  testWidgets('choosing another country selects it with its first zone', (tester) async {
    await show(tester, _choice('KE'));

    await tester.tap(find.byKey(const Key('region-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uganda').last);
    await tester.pumpAndSettle();

    expect(lastChange!.region.code, 'UG');
    expect(lastChange!.zone.ianaId, 'Africa/Kampala');
    expect(find.text('Uganda'), findsOneWidget);
  });

  testWidgets('a country with several zones asks which one, and remembers the pick', (tester) async {
    await show(tester, _choice('US'));

    expect(find.byKey(const Key('region-zone')), findsOneWidget);
    expect(find.text('Eastern Time (UTC-05:00)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('region-zone')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pacific Time (UTC-08:00)').last);
    await tester.pumpAndSettle();

    expect(lastChange!.region.code, 'US');
    expect(lastChange!.zone.windowsId, 'Pacific Standard Time');
    expect(find.text('Pacific Time (UTC-08:00)'), findsOneWidget);
  });

  testWidgets('moving to another multi-zone country shows that country\'s first zone, not the old one', (tester) async {
    await show(tester, _choice('US', zone: 3)); // Pacific

    await tester.tap(find.byKey(const Key('region-country')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Canada').last, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Canada').last);
    await tester.pumpAndSettle();

    expect(lastChange!.region.code, 'CA');
    expect(lastChange!.zone.windowsId, 'Eastern Standard Time');
    expect(find.text('Eastern Time (UTC-05:00)'), findsOneWidget, reason: 'the zone drop-down starts over for the new country');
    expect(find.text('Pacific Time (UTC-08:00)'), findsNothing);
  });

  testWidgets('picking the country that is already selected changes nothing', (tester) async {
    await show(tester, _choice('KE'));

    await tester.tap(find.byKey(const Key('region-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kenya').last);
    await tester.pumpAndSettle();

    expect(lastChange, isNull);
  });
}
