import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/sync_health_notice.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  SyncHealth health({int pending = 0, int quarantined = 0, DateTime? last, DateTime? baseline}) => SyncHealth(
    pendingChanges: pending,
    quarantined: quarantined,
    lastSuccess: last,
    baseline: baseline ?? now.subtract(const Duration(days: 30)),
  );

  test('says nothing when everything is uploading', () {
    expect(syncNoticeFor(health(pending: 3, last: now.subtract(const Duration(minutes: 1))), now), isNull);
  });

  test('says nothing when there is nothing to upload, however long ago the last upload was', () {
    expect(syncNoticeFor(health(pending: 0, last: now.subtract(const Duration(days: 9))), now), isNull);
  });

  test('stays quiet through an ordinary evening offline', () {
    expect(syncNoticeFor(health(pending: 40, last: now.subtract(const Duration(hours: 20))), now), isNull);
  });

  test('speaks up after a day of waiting data that is not uploading', () {
    final notice = syncNoticeFor(health(pending: 40, last: now.subtract(const Duration(hours: 30))), now)!;
    expect(notice.kind, SyncNoticeKind.notUploading);
    expect(notice.title, 'Your data is not reaching the cloud');
    expect(notice.message, contains('30 hours ago'));
    expect(notice.message, contains('40 changes are waiting'));
  });

  test('counts in days once it is a few days', () {
    final notice = syncNoticeFor(health(pending: 1, last: now.subtract(const Duration(days: 5))), now)!;
    expect(notice.message, contains('5 days ago'));
    expect(notice.message, contains('1 change is waiting'.replaceFirst('is waiting', 'are waiting')));
  });

  test('a device that never uploaded anything is measured from when it was first checked', () {
    final recent = syncNoticeFor(health(pending: 5, baseline: now.subtract(const Duration(hours: 3))), now);
    expect(recent, isNull);
    final old = syncNoticeFor(health(pending: 5, baseline: now.subtract(const Duration(days: 2))), now)!;
    expect(old.kind, SyncNoticeKind.notUploading);
    expect(old.message, contains('has not uploaded anything yet'));
  });

  test('refused rows are reported even while uploads are working', () {
    final notice = syncNoticeFor(health(quarantined: 3, last: now.subtract(const Duration(minutes: 2))), now)!;
    expect(notice.kind, SyncNoticeKind.rowsRefused);
    expect(notice.title, '3 records could not be uploaded');
    expect(notice.message, contains('still on this device'));
  });

  test('a single refused row is worded in the singular', () {
    final notice = syncNoticeFor(health(quarantined: 1, last: now), now)!;
    expect(notice.title, '1 record could not be uploaded');
  });

  test('not uploading at all outranks a few refused rows', () {
    final notice = syncNoticeFor(health(pending: 9, quarantined: 2, last: now.subtract(const Duration(days: 3))), now)!;
    expect(notice.kind, SyncNoticeKind.notUploading);
  });
}
