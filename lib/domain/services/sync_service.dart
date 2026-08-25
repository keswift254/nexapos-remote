import 'dart:math' as math;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../../data/local/sync_metadata.dart';
import '../../data/sync/platform_sync_gateway.dart';
import '../../data/sync/sync_table_registry.dart';
import 'paystack_credentials_service.dart';

part 'sync_service.g.dart';

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  return SyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(syncMetadataProvider),
    ref.watch(platformSyncGatewayProvider),
    ref.watch(paystackCredentialsServiceProvider),
  );
}

class _PendingChange {
  final String tableName;
  final Map<String, dynamic> json;
  const _PendingChange(this.tableName, this.json);
}

/// Phase 2 sync: pushes this device's own new/changed rows to
/// nexapos_platform and pulls every other device's, for whichever shop
/// this device belongs to. Reuses PaystackCredentialsService for
/// baseUrl/apiKey rather than a separate store - it's the exact same
/// device identity already used for Paystack calls to the same backend,
/// and that service's own doc comment already anticipated this
/// (device-local, never itself synced).
///
/// Silently no-ops (not configured yet) or swallows network/server
/// failures (tries again next cycle) - a background sync tick must
/// never surface a scary error for "no internet right now", matching
/// how the existing Paystack payment polling behaves.
class SyncService {
  final AppDatabase _db;
  final SyncMetadataService _syncMeta;
  final PlatformSyncGateway _gateway;
  final PaystackCredentialsService _credentials;

  SyncService(this._db, this._syncMeta, this._gateway, this._credentials);

  Future<void> runSyncCycle() async {
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) return;

    try {
      await pushLocalChanges(credentials.baseUrl, credentials.apiKey);
      await pullRemoteChanges(credentials.baseUrl, credentials.apiKey);
    } on PaystackOfflineException {
      // No internet right now - try again next cycle.
    } on PaystackException {
      // Backend rejected something (not yet joined a shop, bad key,
      // ...) - try again next cycle rather than surfacing an error from
      // a background process the user didn't explicitly trigger.
    }
  }

  /// Gathers pending rows across ALL synced tables before sending -
  /// correctness-critical, not stylistic. local_rev is one counter
  /// shared across every table on this device, so a parent row (e.g. a
  /// category) always has a lower rev than a child that references it
  /// (e.g. a product); a per-table push loop could send them out of
  /// that order and violate the invariant every other device's pull
  /// relies on to never see a child before its parent.
  Future<void> pushLocalChanges(String baseUrl, String apiKey) async {
    final deviceId = await _syncMeta.deviceId();
    final sinceRev = await _syncMeta.lastPushedLocalRev();

    final pending = <_PendingChange>[];
    for (final adapter in syncTableAdapters.values) {
      final rows = await adapter.pendingRowsJson(_db, deviceId, sinceRev);
      for (final json in rows) {
        pending.add(_PendingChange(adapter.tableName, json));
      }
    }
    if (pending.isEmpty) return;

    pending.sort((a, b) => (a.json['localRev'] as int).compareTo(b.json['localRev'] as int));

    final batch = pending
        .map((change) => {
              'table_name': change.tableName,
              'row_id': change.json['id'],
              'local_rev': change.json['localRev'],
              'updated_at': change.json['updatedAt'],
              'payload': change.json,
            })
        .toList();

    await _gateway.pushChanges(baseUrl: baseUrl, apiKey: apiKey, changes: batch);

    final maxRev = pending.map((change) => change.json['localRev'] as int).reduce(math.max);
    await _syncMeta.setLastPushedLocalRev(maxRev);
  }

  /// Pages through pull_changes in ascending id order, applying each
  /// page inside its own transaction. A correctly-behaving push never
  /// produces a child-before-parent ordering (see pushLocalChanges), so
  /// PRAGMA defer_foreign_keys is defense in depth for the
  /// should-be-impossible case, not the primary mechanism.
  Future<void> pullRemoteChanges(String baseUrl, String apiKey) async {
    var cursor = await _syncMeta.lastPulledChangeId();
    final touchedProductIds = <String>{};

    while (true) {
      final result = await _gateway.pullChanges(baseUrl: baseUrl, apiKey: apiKey, since: cursor);
      if (result.changes.isEmpty) break;

      await _db.transaction(() async {
        await _db.customStatement('PRAGMA defer_foreign_keys=ON');
        for (final change in result.changes) {
          final adapter = syncTableAdapters[change.tableName];
          if (adapter == null) continue; // unknown table - ignore defensively, never crash a sync cycle over it

          if (adapter.isAppendOnly) {
            await adapter.applyPayload(_db, change.payload);
          } else {
            await _applyWithLastWriteWins(adapter, change);
          }

          if (change.tableName == 'stock_movements') {
            final productId = change.payload['productId'] as String?;
            if (productId != null && productId.isNotEmpty) touchedProductIds.add(productId);
          }
        }
      });

      cursor = result.nextCursor;
      await _syncMeta.setLastPulledChangeId(cursor);
      if (!result.hasMore) break;
    }

    await _recomputeStockQty(touchedProductIds);
  }

  Future<void> _applyWithLastWriteWins(SyncTableAdapter adapter, PulledChange change) async {
    final incomingUpdatedAt = change.payload['updatedAt'] as String? ?? '';
    final incomingDeviceId = change.payload['createdByDeviceId'] as String? ?? '';
    final existing = await adapter.findLocalMeta!(_db, change.rowId);

    // No local copy yet (first time this device has seen the row), or
    // the incoming version is strictly newer, or an exact updated_at
    // tie broken deterministically by device_id - the goal isn't
    // objectively picking the "correct" winner (impossible under wall-
    // clock skew), it's guaranteeing every device converges on the same
    // answer rather than two devices permanently disagreeing.
    final shouldApply = existing == null ||
        incomingUpdatedAt.compareTo(existing.updatedAt) > 0 ||
        (incomingUpdatedAt == existing.updatedAt && incomingDeviceId.compareTo(existing.deviceId) > 0);

    if (shouldApply) {
      await adapter.applyPayload(_db, change.payload);
    }
  }

  /// products.stock_qty is never synced as a plain field (see
  /// sync_table_registry.dart's products adapter) - two devices making
  /// concurrent offline stock movements on the same product would have
  /// one device's edit silently overwrite the other's under plain
  /// last-write-wins. A full re-sum after applying pulled movements is
  /// immune to arrival order and self-healing. This must stay a plain
  /// SQL statement that never touches local_rev/updated_at, or it
  /// manufactures a fake local edit that gets pushed back out and
  /// recomputed again forever.
  Future<void> _recomputeStockQty(Set<String> productIds) async {
    for (final productId in productIds) {
      await _db.customStatement(
        'UPDATE products SET stock_qty = '
        '(SELECT COALESCE(SUM(quantity), 0) FROM stock_movements WHERE product_id = ? AND deleted_at IS NULL) '
        'WHERE id = ?',
        [productId, productId],
      );
    }
  }
}
