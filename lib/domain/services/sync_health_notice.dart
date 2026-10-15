import 'sync_service.dart';

enum SyncNoticeKind {
  /// Data is waiting and nothing has uploaded for a long time.
  notUploading,

  /// The shop server refused some rows for reasons of their own.
  rowsRefused,
}

class SyncNotice {
  final SyncNoticeKind kind;
  final String title;
  final String message;
  const SyncNotice(this.kind, this.title, this.message);
}

/// How long without a successful upload, while data is waiting, before the
/// dashboard says so. Long enough that an ordinary evening offline stays quiet.
const syncStaleAfter = Duration(hours: 24);

/// What (if anything) to tell the person about their data reaching the cloud.
/// Silence for months is how a shop's whole sales history ended up only on one
/// PC, so the app now says so after a day.
SyncNotice? syncNoticeFor(
  SyncHealth health,
  DateTime now, {
  Duration staleAfter = syncStaleAfter,
}) {
  final reference = health.lastSuccess ?? health.baseline;
  final silentFor = now.toUtc().difference(reference.toUtc());
  if (health.pendingChanges > 0 && silentFor > staleAfter) {
    final since = health.lastSuccess == null
        ? 'This device has not uploaded anything yet.'
        : 'The last upload was ${describeSilence(silentFor)} ago.';
    return SyncNotice(
      SyncNoticeKind.notUploading,
      'Your data is not reaching the cloud',
      '$since ${health.pendingChanges} change${health.pendingChanges == 1 ? '' : 's'} '
          'are waiting. Check this device\'s internet connection.',
    );
  }
  if (health.quarantined > 0) {
    final count = health.quarantined;
    return SyncNotice(
      SyncNoticeKind.rowsRefused,
      '$count record${count == 1 ? '' : 's'} could not be uploaded',
      'The shop server refused ${count == 1 ? 'it' : 'them'}. '
          '${count == 1 ? 'It is' : 'They are'} still on this device and in its backups; '
          'everything else is uploading normally. Tap for details.',
    );
  }
  return null;
}

String describeSilence(Duration duration) {
  final days = duration.inDays;
  if (days >= 2) return '$days days';
  final hours = duration.inHours;
  return hours == 1 ? '1 hour' : '$hours hours';
}
