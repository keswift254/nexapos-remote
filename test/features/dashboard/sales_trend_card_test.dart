import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/domain/services/reports_service.dart';
import 'package:nexapos_mobile/features/dashboard/dashboard_screen.dart';

/// "Last 7 Days": tap a day - anywhere in its column - and that day's exact figures are written under the chart,
/// the other days fade. (The same as the Lite till.)
void main() {
  // Mon 9 Nov .. Sun 15 Nov 2026
  List<DailyPoint> week() => [
        for (var i = 0; i < 7; i++)
          DailyPoint(
            date: DateTime(2026, 11, 9 + i),
            salesTotal: Money(100000 + i * 10000),
            expensesTotal: Money(20000 + i * 1000),
            netProfit: Money(i == 3 ? -5000 : 30000 + i * 100),
          ),
      ];

  Future<void> pump(WidgetTester tester, List<DailyPoint> points, {bool visible = true}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SalesTrendCard(points: points, financialsVisible: visible)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Where day [index] is on the screen: the chart's plot area starts after the 36 pixels of numbers on the left, and the seven
  /// groups of bars (27 pixels each) are spread with equal space between and around them.
  Offset dayAt(WidgetTester tester, int index, {double yFraction = 0.5}) {
    final rect = tester.getRect(find.byType(BarChart));
    const left = 36.0;
    const group = 27.0;
    final space = (rect.width - left - 7 * group) / 8;
    final x = rect.left + left + space * (index + 1) + group * index + group / 2;
    return Offset(x, rect.top + rect.height * yFraction);
  }

  String detail(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('trend-detail'))).data!;

  double opacityOf(WidgetTester tester, int day) =>
      tester.widget<BarChart>(find.byType(BarChart)).data.barGroups[day].barRods.first.color!.a;

  testWidgets('says to tap a day, and nothing is chosen at first', (tester) async {
    await pump(tester, week());
    expect(find.text('Tap a day for the exact figures'), findsNWidgets(2), reason: 'under the title and where the figures will appear');
    expect(detail(tester), 'Tap a day for the exact figures');
    for (var d = 0; d < 7; d++) {
      expect(opacityOf(tester, d), 1.0);
    }
  });

  testWidgets('tapping a day shows its date, sales, expenses and net profit under the chart', (tester) async {
    await pump(tester, week());
    await tester.tapAt(dayAt(tester, 2));
    await tester.pumpAndSettle();
    // day 2 = Wed 11 Nov: sales 1,200.00, expenses 220.00, net profit 300.00 + 2 cents? (30200 cents = 302.00)
    expect(detail(tester), contains('Wed, 11 Nov'));
    expect(detail(tester), contains('Sales KES 1,200.00'));
    expect(detail(tester), contains('Expenses KES 220.00'));
    expect(detail(tester), contains('Net Profit KES 302.00'));
  });

  testWidgets('a day is chosen by touching anywhere in its column, high or low, not only on a bar', (tester) async {
    await pump(tester, week());
    await tester.tapAt(dayAt(tester, 5, yFraction: 0.05)); // the empty space above the bars
    await tester.pumpAndSettle();
    expect(detail(tester), contains('Sat, 14 Nov'));
    await tester.tapAt(dayAt(tester, 0, yFraction: 0.3)); // above the bars, nearer the middle
    await tester.pumpAndSettle();
    expect(detail(tester), contains('Mon, 9 Nov'));
    await tester.tapAt(dayAt(tester, 6, yFraction: 0.62)); // on the bars themselves
    await tester.pumpAndSettle();
    expect(detail(tester), contains('Sun, 15 Nov'));
  });

  testWidgets('a loss is shown as a loss', (tester) async {
    await pump(tester, week());
    await tester.tapAt(dayAt(tester, 3));
    await tester.pumpAndSettle();
    expect(detail(tester), contains('Thu, 12 Nov'));
    expect(detail(tester), contains('Net Profit -KES 50.00'));
  });

  testWidgets('the days that were not tapped fade, the tapped one stays as it was', (tester) async {
    await pump(tester, week());
    await tester.tapAt(dayAt(tester, 4));
    await tester.pumpAndSettle();
    for (var d = 0; d < 7; d++) {
      expect(opacityOf(tester, d), d == 4 ? 1.0 : closeTo(0.3, 0.01), reason: 'day $d');
    }
    await tester.tapAt(dayAt(tester, 1));
    await tester.pumpAndSettle();
    expect(opacityOf(tester, 4), closeTo(0.3, 0.01));
    expect(opacityOf(tester, 1), 1.0);
  });

  testWidgets('with the figures hidden the tapped day shows stars, not money (the date still shows)', (tester) async {
    await pump(tester, week(), visible: false);
    await tester.tapAt(dayAt(tester, 2));
    await tester.pumpAndSettle();
    expect(detail(tester), contains('Wed, 11 Nov'));
    expect(detail(tester), contains('Sales ******'));
    expect(detail(tester), contains('Expenses ******'));
    expect(detail(tester), contains('Net Profit ******'));
    expect(detail(tester), isNot(contains('KES')));
  });

  testWidgets('new figures (another day, a refresh) clear the choice', (tester) async {
    await pump(tester, week());
    await tester.tapAt(dayAt(tester, 2));
    await tester.pumpAndSettle();
    expect(detail(tester), contains('Wed, 11 Nov'));
    await pump(tester, week()); // a different list object
    expect(detail(tester), 'Tap a day for the exact figures');
    expect(opacityOf(tester, 2), 1.0);
  });

  testWidgets('there is no pop-up over the bars any more: the figures are only under the chart', (tester) async {
    await pump(tester, week());
    await tester.tapAt(dayAt(tester, 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Wed, 11 Nov'), findsOneWidget);
  });
}
