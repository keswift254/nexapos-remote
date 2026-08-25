import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexapos_mobile/app.dart';
import 'package:nexapos_mobile/core/providers.dart';
import 'package:nexapos_mobile/data/local/database.dart';
import 'package:nexapos_mobile/domain/services/license_service.dart';

void main() {
  testWidgets('fresh install with no users lands on the setup screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
          // Setup/login is what this test exercises - licensing is covered
          // separately by activation_flow_test.dart.
          hasCachedLicenseProvider.overrideWith((ref) async => true),
        ],
        child: const NexaPosApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up NexaPOS'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
