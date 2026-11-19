import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/features/settings/settings_menu_screen.dart';

class _Session extends SessionNotifier {
  _Session(this.role);

  final UserRole role;

  @override
  User? build() => User(
        id: 'user-1',
        role: role,
        name: 'Someone',
        username: 'someone',
        passwordHash: '',
        status: 'active',
      );
}

const _adminTitles = [
  'Security & Privacy',
  'Business, Receipts & Themes',
  'Payments & Payouts',
  'M-Pesa Till Phone',
  'Sync & Invites',
  'Devices in This Shop',
  'Backup & Restore',
  'Date, Time & Region',
  'My License',
  'Software Update',
];

const _everyoneTitles = ['Security & Privacy', 'My License', 'Software Update'];

Future<GoRouter> _open(WidgetTester tester, UserRole role, {Size size = const Size(800, 1200), ThemeData? theme}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Dashboard'))),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsMenuScreen()),
      for (final entry in settingsMenuEntries)
        GoRoute(
          path: entry.route,
          builder: (_, _) => Scaffold(appBar: AppBar(), body: Text('Opened ${entry.route}')),
        ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [sessionProvider.overrideWith(() => _Session(role))],
    child: MaterialApp.router(routerConfig: router, theme: theme),
  ));
  await tester.pumpAndSettle();
  return router;
}

/// The row titles, top to bottom.
List<String> _shownTitles(WidgetTester tester) {
  final rows = tester.widgetList<SettingsMenuRow>(find.byType(SettingsMenuRow)).toList();
  final placed = [
    for (final row in rows) (row.title, tester.getTopLeft(find.byWidget(row)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final p in placed) p.$1];
}

void main() {
  testWidgets('an administrator sees every settings page, in the same order as before', (tester) async {
    await _open(tester, UserRole.admin);
    expect(find.text('Settings'), findsOneWidget);
    expect(_shownTitles(tester), _adminTitles);
  });

  for (final role in [UserRole.manager, UserRole.cashier]) {
    testWidgets('${role.name}s see only the pages everyone may open', (tester) async {
      await _open(tester, role);
      expect(_shownTitles(tester), _everyoneTitles);
      for (final title in _adminTitles.where((t) => !_everyoneTitles.contains(t))) {
        expect(find.text(title), findsNothing, reason: title);
      }
    });
  }

  testWidgets('each row opens its page, and back returns to Settings', (tester) async {
    await _open(tester, UserRole.admin);
    for (final entry in settingsMenuEntries) {
      await tester.tap(find.text(entry.title));
      await tester.pumpAndSettle();
      expect(find.text('Opened ${entry.route}'), findsOneWidget, reason: entry.title);
      expect(find.byType(SettingsMenuScreen), findsNothing, reason: entry.title);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Opened ${entry.route}'), findsNothing, reason: entry.title);
      expect(find.byType(SettingsMenuScreen), findsOneWidget, reason: entry.title);
    }
  });

  testWidgets('rows look like the Lite till: rounded raised tiles in the low surface colour with a chevron', (tester) async {
    await _open(tester, UserRole.admin);
    final scheme = Theme.of(tester.element(find.byType(SettingsMenuScreen))).colorScheme;
    final row = find.byKey(const Key('settings-row-/privacy-settings'));
    final material = tester.widget<Material>(find.descendant(of: row, matching: find.byType(Material)).first);
    expect(material.color, scheme.surfaceContainerLow);
    expect(material.elevation, 1);
    expect(material.surfaceTintColor, Colors.transparent);
    expect((material.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(12));
    expect(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
    final title = tester.widget<Text>(find.descendant(of: row, matching: find.text('Security & Privacy')));
    expect(title.style!.fontSize, 16);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(52 + 8));
    // 8 between rows, as in Lite
    final next = find.byKey(const Key('settings-row-/business-settings'));
    expect(tester.getTopLeft(next).dy - tester.getBottomLeft(row).dy, 0);
    expect(tester.getTopLeft(find.descendant(of: next, matching: find.byType(Material)).first).dy -
        tester.getBottomLeft(find.descendant(of: row, matching: find.byType(Material)).first).dy, 8);
  });

  testWidgets('the colours follow the shop theme (dark too)', (tester) async {
    final dark = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark));
    await _open(tester, UserRole.admin, theme: dark);
    final row = find.byKey(const Key('settings-row-/license'));
    final material = tester.widget<Material>(find.descendant(of: row, matching: find.byType(Material)).first);
    expect(material.color, dark.colorScheme.surfaceContainerLow);
    final icon = tester.widget<Icon>(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)));
    expect(icon.color, dark.colorScheme.onSurfaceVariant);
  });

  testWidgets('on a 360-pixel phone the rows fill the width and nothing overflows', (tester) async {
    await _open(tester, UserRole.admin, size: const Size(360, 640));
    expect(tester.takeException(), isNull);
    final tile = find.descendant(of: find.byKey(const Key('settings-row-/business-settings')), matching: find.byType(Material)).first;
    expect(tester.getSize(tile).width, 360 - 32);
    expect(tester.getTopLeft(tile).dx, 16);
    // the last rows are reachable by scrolling
    await tester.scrollUntilVisible(find.text('Software Update'), 200);
    expect(find.text('Software Update'), findsOneWidget);
  });

  testWidgets('on a wide screen the rows stay in one centred column, as wide as Lite', (tester) async {
    await _open(tester, UserRole.admin, size: const Size(1600, 1000));
    final tile = find.descendant(of: find.byKey(const Key('settings-row-/privacy-settings')), matching: find.byType(Material)).first;
    expect(tester.getSize(tile).width, SettingsMenuScreen.maxWidth - 32);
    expect(tester.getTopLeft(tile).dx, (1600 - SettingsMenuScreen.maxWidth) / 2 + 16);
  });
}
