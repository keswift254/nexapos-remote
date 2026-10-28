import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/google_drive_backup_service.dart';
import 'package:nexapos_mobile/features/settings/google_drive_backup_screen.dart';

/// A Drive service that answers from a script instead of Google.
class _FakeDrive implements GoogleDriveBackupService {
  _FakeDrive(this.onList);

  Future<List<GoogleDriveBackupSummary>> Function() onList;
  int listCalls = 0;

  @override
  Future<String?> connectedEmail() async => 'owner@gmail.com';

  @override
  Future<List<GoogleDriveBackupSummary>> listBackups() {
    listCalls++;
    return onList();
  }

  @override
  Future<String> connect({required String recoveryPassphrase}) async =>
      'owner@gmail.com';

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> uploadLatestBackupIfConnected() async {}

  @override
  Future<Uint8List> downloadBackup(String fileId) async => Uint8List(0);

  @override
  Future<Uint8List> recoverBackupKey({
    required String recoveryPassphrase,
  }) async => Uint8List(0);
}

Future<void> _show(WidgetTester tester, _FakeDrive drive) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [googleDriveBackupServiceProvider.overrideWithValue(drive)],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GoogleDriveBackupSection()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

GoogleDriveBackupSummary _backup(String name, int bytes) =>
    GoogleDriveBackupSummary(
      fileId: name,
      name: name,
      modifiedAt: DateTime.utc(2026, 10, 27, 8),
      sizeBytes: bytes,
    );

void main() {
  testWidgets('lists the backups on Drive with a Restore button each', (
    tester,
  ) async {
    await _show(
      tester,
      _FakeDrive(() async => [_backup('a', 2048), _backup('b', 4096)]),
    );
    expect(find.text('Connected as owner@gmail.com'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    expect(find.text('4 KB'), findsOneWidget);
    expect(find.text('Restore'), findsNWidgets(2));
    expect(find.text('Reconnect'), findsNothing);
  });

  testWidgets(
    'says so, and offers Reconnect, when Google no longer accepts the saved sign-in',
    (tester) async {
      await _show(
        tester,
        _FakeDrive(
          () => Future.error(const GoogleDriveReconnectRequiredException()),
        ),
      );
      expect(
        find.text(
          'Google Drive sign-in expired or was removed. Tap Reconnect to sign in again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.textContaining('Instance of'), findsNothing);
    },
  );

  testWidgets(
    'a build without Google access says to update, with nothing to tap',
    (tester) async {
      await _show(
        tester,
        _FakeDrive(
          () => Future.error(
            const GoogleDriveUnavailableException(
              'Update NexaPOS to the latest version.',
            ),
          ),
        ),
      );
      expect(
        find.text('Update NexaPOS to the latest version.'),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    },
  );

  testWidgets(
    'any other failure can be retried, and the retry loads the list',
    (tester) async {
      final drive = _FakeDrive(() => Future.error(StateError('offline')));
      await _show(tester, drive);
      expect(find.textContaining('Could not list backups'), findsOneWidget);
      expect(find.text('Reconnect'), findsNothing);
      expect(drive.listCalls, 1);

      drive.onList = () async => [_backup('a', 1024)];
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(drive.listCalls, 2);
      expect(find.text('1 KB'), findsOneWidget);
      expect(find.textContaining('Could not list backups'), findsNothing);
    },
  );

  testWidgets('a list that never answers stops spinning and offers Try again', (
    tester,
  ) async {
    final never = Completer<List<GoogleDriveBackupSummary>>();
    await _show(tester, _FakeDrive(() => never.future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(googleDriveListTimeout + const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('did not answer in time'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
