// The "contract" between the real app and anything else that writes EXPENSES into a shop's sync (the old-iPad Lite till,
// and the platform's sync guard that checks its records) - the same idea as sync_contract_fixtures_test.dart for sales.
//
// Real expenses are created and deleted through the real ExpenseService and the exact sync records the app would send are
// captured. They are compared (with ids and times masked) against test/fixtures/sync/expense_scenarios.json, which is also
// copied into the platform repo as the fixtures its guard must accept. If the app's expense record format ever changes this
// test fails: the signal to update the guard and the Lite till BEFORE shipping the change.
//
// To refresh the file after an intended change:
//   UPDATE_SYNC_FIXTURES=1 flutter test test/tool/expense_contract_fixtures_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Expense, Product, User;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/expense_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/sync_table_registry.dart';
import 'package:nexapos_mobile/domain/entities/expense.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/expense_service.dart';

const _fixturePath = 'test/fixtures/sync/expense_scenarios.json';

void main() {
  late AppDatabase db;
  late ExpenseService expenses;
  late String deviceId;
  late String userId;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final ids = UuidIdGenerator();
    expenses = ExpenseService(ExpenseRepositoryImpl(db, db.expensesDao, syncMeta, clock, ids), ids, clock);
    deviceId = await syncMeta.deviceId();
    final user = User(
      id: ids.newId(),
      role: UserRole.admin,
      name: 'Owner',
      username: 'owner',
      passwordHash: r'$2a$10$irrelevantirrelevantirrelevantirrelevantirrelevan',
      status: 'active',
    );
    await UserRepositoryImpl(db, db.usersDao, syncMeta, clock, ids).create(user);
    userId = user.id;
  });

  tearDown(() async => db.close());

  /// Every expense record written since [sinceRev], as the app would push it.
  Future<List<Map<String, dynamic>>> changesSince(int sinceRev) async {
    final rows = await syncTableAdapters['expenses']!.pendingRowsJson(db, deviceId, sinceRev);
    final out = [
      for (final payload in rows)
        {
          'table_name': 'expenses',
          'row_id': payload['id'],
          'local_rev': payload['localRev'],
          'updated_at': payload['updatedAt'],
          'payload': payload,
        },
    ];
    out.sort((a, b) => (a['local_rev'] as int).compareTo(b['local_rev'] as int));
    return out;
  }

  Future<Map<String, dynamic>> context() async => {
        'deviceId': deviceId,
        'userId': userId,
        'users': await syncTableAdapters['users']!.pendingRowsJson(db, deviceId, 0),
      };

  Future<Map<String, dynamic>> scenario(String name, String what, List<Future<void> Function()> stages) async {
    final outStages = <Map<String, dynamic>>[];
    var since = await _maxRev(db, deviceId); // only this scenario's records, not the earlier ones'
    var index = 0;
    for (final run in stages) {
      await run();
      final changes = await changesSince(since);
      since = changes.map((c) => c['local_rev'] as int).fold(since, (a, b) => a > b ? a : b);
      outStages.add({'stage': ++index, 'changes': changes});
    }
    return {'name': name, 'what': what, 'context': await context(), 'stages': outStages};
  }

  Future<Expense> create({String? user, String title = 'Transport', int cents = 250000, String? note, DateTime? date}) async {
    late Expense made;
    (await expenses.create(
      expenseDate: date ?? DateTime(2026, 11, 5),
      title: title,
      amount: Money(cents),
      note: note,
      userId: user,
    ))
        .when(ok: (e) => made = e, failure: (m) => fail(m));
    return made;
  }

  test('the sync records the app produces match the committed contract', () async {
    // Masks everything that legitimately differs between runs.
    String mask(Object? value) => jsonEncode(value)
        .replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'), '<id>')
        .replaceAll(RegExp(r'\d{4}-\d\d-\d\dT[\d:.]+Z?'), '<time>')
        .replaceAll(RegExp(r'"(local_rev|localRev)":\d+'), r'"rev":0')
        .replaceAll(RegExp(r'"(stage|createdAt|updatedAt|deletedAt)":"?[^,}"]*"?'), '"x":0');

    // Build the scenarios again here (each test has its own database).
    final fresh = <Map<String, dynamic>>[];
    fresh.add(await scenario('expense_with_user_and_note', 'An expense entered by a logged-in user, with a note.', [
      () async => create(user: userId, title: 'Transport', cents: 250050, note: 'Delivery to Kisumu'),
    ]));
    fresh.add(await scenario('expense_without_user_or_note', 'An expense with no user recorded and no note (a blank note is stored as null).', [
      () async => create(user: null, title: 'Water', cents: 15000, note: '   '),
    ]));
    fresh.add(await scenario('expense_with_trimmed_name', 'The name is trimmed before it is stored.', [
      () async => create(user: userId, title: '   Packaging   ', cents: 99, note: null, date: DateTime(2026, 1, 31)),
    ]));
    late Expense gone;
    fresh.add(await scenario('expense_created_then_deleted', 'An expense that is deleted afterwards (a soft delete: deletedAt and updatedAt set, a new revision).', [
      () async => gone = await create(user: userId, title: 'Wrong entry', cents: 7500, note: 'typo'),
      () async => (await expenses.delete(gone.id)).when(ok: (_) {}, failure: (m) => fail(m)),
    ]));

    final ordered = [...fresh]..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final file = File(_fixturePath);
    if (Platform.environment['UPDATE_SYNC_FIXTURES'] == '1') {
      file.createSync(recursive: true);
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'generated_by': 'test/tool/expense_contract_fixtures_test.dart', 'scenarios': ordered})}\n');
      // ignore: avoid_print
      print('Wrote $_fixturePath (${ordered.length} scenarios).');
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'Missing $_fixturePath - run with UPDATE_SYNC_FIXTURES=1 once.');
    final committed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final committedScenarios = (committed['scenarios'] as List).cast<Map<String, dynamic>>();
    expect(ordered.map((s) => s['name']), committedScenarios.map((s) => s['name']));
    for (var i = 0; i < ordered.length; i++) {
      expect(
        mask(ordered[i]['stages']),
        mask(committedScenarios[i]['stages']),
        reason: 'The sync records for "${ordered[i]['name']}" changed. The platform sync guard and the Lite till '
            'must be updated to match BEFORE this ships; then refresh the fixtures with UPDATE_SYNC_FIXTURES=1.',
      );
    }
  });
}

Future<int> _maxRev(AppDatabase db, String deviceId) async {
  var max = 0;
  for (final adapter in syncTableAdapters.values) {
    for (final row in await adapter.pendingRowsJson(db, deviceId, 0)) {
      final rev = row['localRev'] as int;
      if (rev > max) max = rev;
    }
  }
  return max;
}
