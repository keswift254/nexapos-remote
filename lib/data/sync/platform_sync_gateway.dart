import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../payments/platform_http_client.dart';

export '../payments/platform_http_client.dart'
    show PaystackException, PaystackOfflineException;

part 'platform_sync_gateway.g.dart';

@Riverpod(keepAlive: true)
PlatformSyncGateway platformSyncGateway(Ref ref) => PlatformSyncGateway();

/// A routine cloud request that was given up on because a change from another
/// device on the LAN needed to be applied (see [PlatformSyncGateway.holdRequests]).
class SyncRequestAbandoned implements Exception {
  const SyncRequestAbandoned();

  @override
  String toString() => 'The request was set aside for a nearby device.';
}

class PulledChange {
  final int id;
  final String tableName;
  final String rowId;
  final Map<String, dynamic> payload;

  const PulledChange({
    required this.id,
    required this.tableName,
    required this.rowId,
    required this.payload,
  });
}

class PullResult {
  final List<PulledChange> changes;
  final int nextCursor;
  final bool hasMore;

  const PullResult({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });
}

class SyncSnapshotPage {
  final String snapshotId;
  final int highWater;
  final int total;
  final PullResult page;
  const SyncSnapshotPage(
    this.snapshotId,
    this.highWater,
    this.total,
    this.page,
  );

  factory SyncSnapshotPage.fromJson(Map<String, dynamic> response) {
    return SyncSnapshotPage(
      response['snapshot_id'] as String,
      (response['high_water'] as num).toInt(),
      (response['total'] as num).toInt(),
      PullResult(
        changes: ((response['changes'] as List?) ?? const []).map((raw) {
          final change = raw as Map;
          return PulledChange(
            id: (change['id'] as num).toInt(),
            tableName: change['table_name'] as String,
            rowId: change['row_id'] as String,
            payload: (change['payload'] as Map).cast<String, dynamic>(),
          );
        }).toList(),
        nextCursor: (response['next_cursor'] as num?)?.toInt() ?? 0,
        hasMore: response['has_more'] == true,
      ),
    );
  }
}

/// Thin HTTP client for the two sync-data endpoints on the payments
/// platform backend - kept separate from PlatformOnboardingGateway
/// (setup-time device/shop identity) and PaystackGateway (checkout-time
/// payments), since this is the recurring data-loop concern, following
/// the same platformRequest() plumbing both of those already use.
class PlatformSyncGateway {
  final http.Client _client;

  PlatformSyncGateway([http.Client? client])
    : _client = client ?? http.Client();

  // A cloud sync that is waiting on the server must not keep a change that
  // arrived from the till next to it (over the LAN) waiting too: those two
  // devices are a metre apart and the server may be a slow internet route away.
  // While a LAN change is being applied ([holdRequests]) the routine push/pull
  // requests give up at once - and a request already waiting is abandoned - so
  // the cloud cycle ends and the change goes in immediately. The cycle simply
  // runs again on its next turn; nothing is lost, because a request that was
  // abandoned is treated exactly like one that timed out (both are retried).
  final Set<Completer<Never>> _waiting = {};
  int _holds = 0;

  /// Stops the routine push/pull requests (abandoning any that are waiting)
  /// until the matching [releaseRequests].
  void holdRequests() {
    _holds++;
    for (final waiting in _waiting.toList()) {
      if (!waiting.isCompleted) waiting.completeError(const SyncRequestAbandoned());
    }
    _waiting.clear();
  }

  void releaseRequests() {
    if (_holds > 0) _holds--;
  }

  /// Sends the request unless requests are being held (then it is never sent),
  /// and gives up waiting for it if they become held while it is out.
  Future<T> _abandonable<T>(Future<T> Function() send) {
    if (_holds > 0) return Future<T>.error(const SyncRequestAbandoned());
    final abandon = Completer<Never>();
    _waiting.add(abandon);
    return Future.any<T>([send(), abandon.future]).whenComplete(() => _waiting.remove(abandon));
  }

  Future<SyncSnapshotPage> startSnapshot(String baseUrl, String apiKey) async =>
      SyncSnapshotPage.fromJson(
        await platformRequest(
          _client,
          'POST',
          'start_sync_snapshot',
          baseUrl,
          apiKey: apiKey,
          body: const {},
          timeout: platformSyncRequestTimeout,
        ),
      );

  Future<void> discardSnapshot(String baseUrl, String apiKey, String id) async {
    await platformRequest(
      _client,
      'POST',
      'discard_sync_snapshot',
      baseUrl,
      apiKey: apiKey,
      body: {'snapshot_id': id},
      timeout: platformSyncRequestTimeout,
    );
  }

  Future<SyncSnapshotPage> pullSnapshot(
    String baseUrl,
    String apiKey,
    String id,
    int after,
  ) async => SyncSnapshotPage.fromJson(
    await platformRequest(
      _client,
      'GET',
      'pull_sync_snapshot',
      baseUrl,
      apiKey: apiKey,
      queryParameters: {'snapshot_id': id, 'after': '$after'},
      timeout: platformSyncRequestTimeout,
    ),
  );

  /// [changes] must already be in ascending local_rev order across
  /// every table, not just within one table - the backend inserts them
  /// one at a time in the given array order, and local_rev is one
  /// counter shared across every synced table on this device, so
  /// preserving that order is what guarantees a parent row's change
  /// (e.g. a category) is always logged before a child that references
  /// it (e.g. a product), for every other device's pull to rely on.
  Future<void> pushChanges({
    required String baseUrl,
    required String apiKey,
    required List<Map<String, dynamic>> changes,
  }) async {
    if (changes.isEmpty) return;
    final response = await _abandonable(() => platformRequest(
      _client,
      'POST',
      'push_changes',
      baseUrl,
      apiKey: apiKey,
      body: {'changes': changes},
      timeout: platformSyncRequestTimeout,
    ));
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not push changes.'),
      );
    }
  }

  Future<PullResult> pullChanges({
    required String baseUrl,
    required String apiKey,
    required int since,
  }) async {
    final response = await _abandonable(() => platformRequest(
      _client,
      'GET',
      'pull_changes',
      baseUrl,
      apiKey: apiKey,
      queryParameters: {'since': '$since'},
      timeout: platformSyncRequestTimeout,
    ));
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not pull changes.'),
      );
    }
    final rawChanges = (response['changes'] as List?) ?? const [];
    final changes = rawChanges.whereType<Map>().map((change) {
      return PulledChange(
        id: (change['id'] as num).toInt(),
        tableName: (change['table_name'] as String? ?? '').trim(),
        rowId: (change['row_id'] as String? ?? '').trim(),
        payload:
            (change['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    }).toList();
    return PullResult(
      changes: changes,
      nextCursor: (response['next_cursor'] as num?)?.toInt() ?? since,
      hasMore: response['has_more'] == true,
    );
  }
}
