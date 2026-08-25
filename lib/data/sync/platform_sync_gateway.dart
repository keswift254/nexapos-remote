import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../payments/platform_http_client.dart';

export '../payments/platform_http_client.dart' show PaystackException, PaystackOfflineException;

part 'platform_sync_gateway.g.dart';

@Riverpod(keepAlive: true)
PlatformSyncGateway platformSyncGateway(Ref ref) => PlatformSyncGateway();

class PulledChange {
  final int id;
  final String tableName;
  final String rowId;
  final Map<String, dynamic> payload;

  const PulledChange({required this.id, required this.tableName, required this.rowId, required this.payload});
}

class PullResult {
  final List<PulledChange> changes;
  final int nextCursor;
  final bool hasMore;

  const PullResult({required this.changes, required this.nextCursor, required this.hasMore});
}

/// Thin HTTP client for the two sync-data endpoints on the payments
/// platform backend - kept separate from PlatformOnboardingGateway
/// (setup-time device/shop identity) and PaystackGateway (checkout-time
/// payments), since this is the recurring data-loop concern, following
/// the same platformRequest() plumbing both of those already use.
class PlatformSyncGateway {
  final http.Client _client;

  PlatformSyncGateway([http.Client? client]) : _client = client ?? http.Client();

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
    final response = await platformRequest(
      _client,
      'POST',
      'push_changes',
      baseUrl,
      apiKey: apiKey,
      body: {'changes': changes},
    );
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not push changes.'));
    }
  }

  Future<PullResult> pullChanges({required String baseUrl, required String apiKey, required int since}) async {
    final response = await platformRequest(
      _client,
      'GET',
      'pull_changes',
      baseUrl,
      apiKey: apiKey,
      queryParameters: {'since': '$since'},
    );
    if (response['success'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Could not pull changes.'));
    }
    final rawChanges = (response['changes'] as List?) ?? const [];
    final changes = rawChanges.whereType<Map>().map((change) {
      return PulledChange(
        id: (change['id'] as num).toInt(),
        tableName: (change['table_name'] as String? ?? '').trim(),
        rowId: (change['row_id'] as String? ?? '').trim(),
        payload: (change['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
    }).toList();
    return PullResult(
      changes: changes,
      nextCursor: (response['next_cursor'] as num?)?.toInt() ?? since,
      hasMore: response['has_more'] == true,
    );
  }
}
