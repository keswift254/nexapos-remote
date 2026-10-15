import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/session_service.dart';
import 'package:nexapos_mobile/domain/services/sync_health_notice.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';
import 'package:nexapos_mobile/features/dashboard/sync_health_banner.dart';

class _Session extends SessionNotifier {
  _Session(this.role);
  final UserRole role;

  @override
  User? build() => User(id: 'u', role: role, name: 'Test User', username: 'tester', passwordHash: '', status: 'active');
}

void main() {
  late List<String> pushed;

  Future<void> show(
    WidgetTester tester, {
    SyncNotice? notice,
    UserRole role = UserRole.admin,
    List<QuarantineGroup> groups = const [],
    bool failToLook = false,
  }) async {
    pushed = [];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SyncHealthBanner())),
      GoRoute(
        path: '/device-sync',
        builder: (_, _) {
          pushed.add('/device-sync');
          return const Scaffold(body: Text('Device Sync page'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(role)),
        syncNoticeProvider.overrideWith((ref) async {
          if (failToLook) throw StateError('database not ready');
          return notice;
        }),
        quarantineGroupsProvider.overrideWith((ref) async => groups),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  const bannerKey = Key('sync-health-banner');
  const stale = SyncNotice(
    SyncNoticeKind.notUploading,
    'Your data is not reaching the cloud',
    'The last upload was 3 days ago. 40 changes are waiting. Check this device\'s internet connection.',
  );
  const refused = SyncNotice(
    SyncNoticeKind.rowsRefused,
    '3 records could not be uploaded',
    'The shop server refused them. They are still on this device and in its backups; everything else is uploading normally. Tap for details.',
  );

  testWidgets('shows nothing while all is well', (tester) async {
    await show(tester);
    expect(find.byKey(bannerKey), findsNothing);
  });

  testWidgets('shows nothing - and does not crash the dashboard - when it cannot look', (tester) async {
    await show(tester, failToLook: true);
    expect(find.byKey(bannerKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warns when data is not reaching the cloud', (tester) async {
    await show(tester, notice: stale);
    expect(find.byKey(bannerKey), findsOneWidget);
    expect(find.text('Your data is not reaching the cloud'), findsOneWidget);
    expect(find.textContaining('3 days ago'), findsOneWidget);
  });

  testWidgets('tapping a refused-rows warning lists what the server said, grouped', (tester) async {
    await show(tester, notice: refused, groups: const [
      QuarantineGroup('sales', 'Change is dated more than a day in the future - check this device\'s date and time.', 2),
      QuarantineGroup('products', 'Change payload is too large.', 1),
    ]);
    await tester.tap(find.byKey(bannerKey));
    await tester.pumpAndSettle();

    expect(find.text('What the server said:'), findsOneWidget);
    expect(find.textContaining('2 x sales: Change is dated more than a day in the future'), findsOneWidget);
    expect(find.textContaining('1 x products: Change payload is too large.'), findsOneWidget);
    expect(find.textContaining('Nothing has been deleted'), findsOneWidget);
  });

  testWidgets('an admin can jump to Device Sync from the details', (tester) async {
    await show(tester, notice: stale);
    await tester.tap(find.byKey(bannerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sync-health-open-device-sync')));
    await tester.pumpAndSettle();
    expect(pushed, ['/device-sync']);
  });

  testWidgets('anyone else just reads it and closes it', (tester) async {
    await show(tester, notice: stale, role: UserRole.cashier);
    await tester.tap(find.byKey(bannerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-health-open-device-sync')), findsNothing);
    await tester.tap(find.byKey(const Key('sync-health-close')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
