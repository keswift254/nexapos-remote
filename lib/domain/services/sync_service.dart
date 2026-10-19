import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show QueryRow, Variable;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../../data/local/sync_metadata.dart';
import '../../data/sync/platform_sync_gateway.dart';
import '../../data/sync/server_reachability.dart';
import '../../data/sync/sync_table_registry.dart';
import '../../data/payments/platform_onboarding_gateway.dart';
import 'paystack_credentials_service.dart';
import 'license_service.dart';

part 'sync_service.g.dart';

/// How often app.dart's background timer retries while a device is still
/// waiting on its first shop snapshot (SyncProgress.busy false, but
/// needsInitialPull true) - much shorter than the app's normal steady-state
/// sync cadence, since there's known, immediate work left rather than just
/// checking in. Shared with device_sync_screen.dart's join-progress screen
/// so its "retrying automatically every Xs" text can never drift out of
/// sync with the timer that actually governs it.
const hydratingSyncRetryInterval = Duration(seconds: 5);

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  return SyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(syncMetadataProvider),
    ref.watch(platformSyncGatewayProvider),
    ref.watch(paystackCredentialsServiceProvider),
    canSync: () => ref.read(licenseServiceProvider).hasAppAccess(),
    isReachable: serverReachable,
  );
}

class _PendingChange {
  final String tableName;
  final Map<String, dynamic> json;
  const _PendingChange(this.tableName, this.json);
}

/// Counts how much of a cycle's budget for isolating refused rows is left.
class _Isolation {
  _Isolation(this.requestsLeft);
  int requestsLeft;
  int quarantinedThisCycle = 0;
}

/// Rows of one table the shop server refused for the same reason.
class QuarantineGroup {
  final String tableName;
  final String reason;
  final int count;
  const QuarantineGroup(this.tableName, this.reason, this.count);
}

/// How well this device's data is reaching the cloud.
class SyncHealth {
  final int pendingChanges;
  final int quarantined;
  final DateTime? lastSuccess;

  /// When this device first checked: the reference for "no upload for a day"
  /// on a device that has no recorded upload at all yet.
  final DateTime baseline;
  const SyncHealth({
    required this.pendingChanges,
    required this.quarantined,
    required this.lastSuccess,
    required this.baseline,
  });
}

class LanSyncChange {
  final String sourceDeviceId;
  final String tableName;
  final String rowId;
  final int localRev;
  final String updatedAt;
  final Map<String, dynamic> payload;

  const LanSyncChange({
    required this.sourceDeviceId,
    required this.tableName,
    required this.rowId,
    required this.localRev,
    required this.updatedAt,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'source_device_id': sourceDeviceId,
    'table_name': tableName,
    'row_id': rowId,
    'local_rev': localRev,
    'updated_at': updatedAt,
    'payload': payload,
  };

  factory LanSyncChange.fromJson(Map<String, dynamic> json) => LanSyncChange(
    sourceDeviceId: json['source_device_id'] as String? ?? '',
    tableName: json['table_name'] as String? ?? '',
    rowId: json['row_id'] as String? ?? '',
    localRev: (json['local_rev'] as num? ?? 0).toInt(),
    updatedAt: json['updated_at'] as String? ?? '',
    payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

class SyncProgress {
  final String message;
  final int completed;
  final int? total;
  final bool busy;
  const SyncProgress(
    this.message, {
    this.completed = 0,
    this.total,
    this.busy = false,
  });
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
  static const _pushBatchSize = 200;

  final AppDatabase _db;
  final SyncMetadataService _syncMeta;
  final PlatformSyncGateway _gateway;
  final PaystackCredentialsService _credentials;
  final PlatformOnboardingGateway _onboarding;
  final Future<bool> Function()? canSync;

  /// Asked before a cloud cycle takes its place in the exclusive queue: can the
  /// server be reached at all right now? (See serverReachable for why.) Null =
  /// never ask, which is what the tests want.
  final Future<bool> Function(String baseUrl)? isReachable;

  SyncService(
    this._db,
    this._syncMeta,
    this._gateway,
    this._credentials, {
    PlatformOnboardingGateway? onboarding,
    this.canSync,
    this.isReachable,
  }) : _onboarding = onboarding ?? PlatformOnboardingGateway();

  Future<void> _tail = Future.value();
  String? lastError;
  DateTime? lastSuccess;
  final progress = ValueNotifier<SyncProgress>(
    const SyncProgress('Ready to sync'),
  );

  /// completed/total default to whatever is already showing, not to 0/null -
  /// a step that has no number of its own to report (an on-network "checking
  /// for X" message before it knows X, say) must not blank out a real count
  /// a previous step already established, or a device retrying every few
  /// seconds while it downloads its shop would see the screen reset itself
  /// on every single retry instead of just climbing (confirmed: this exact
  /// thing happened here). A step that genuinely starts counting from
  /// nothing (a snapshot download that has never made any progress yet)
  /// passes completed: 0 itself, same as it always could.
  void _progress(
    String message, {
    int? completed,
    int? total,
    bool busy = true,
  }) {
    progress.value = SyncProgress(
      message,
      completed: completed ?? progress.value.completed,
      total: total ?? progress.value.total,
      busy: busy,
    );
  }

  Future<T> exclusive<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> get hasPendingShopChange async =>
      (await _db
              .customSelect(
                "SELECT id FROM local_safety_state WHERE id='shop_change'",
              )
              .get())
          .isNotEmpty;

  Future<bool> get needsInitialPull async =>
      (await _db
              .customSelect(
                "SELECT id FROM local_safety_state WHERE id='shop_hydration'",
              )
              .get())
          .isNotEmpty;

  Future<void> prepareJoinedShop() => _db.transaction(() async {
    await _db.customStatement(
      "DELETE FROM local_safety_state WHERE id='sync_snapshot'",
    );
    await _db.delete(_db.businessSettings).go();
    final meta = await _db.select(_db.deviceMeta).getSingle();
    await _syncMeta.setLastPushedLocalRev(meta.nextLocalRev - 1);
    await _syncMeta.setLastPulledChangeId(0);
    await _db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('shop_hydration','pending')",
    );
  });

  Future<void> prepareInitialJoin(int sourceShop) => _db.transaction(() async {
    if (sourceShop <= 0) {
      throw StateError('Update the platform before joining a shop.');
    }
    for (final table in _db.allTables.where(
      (t) => ![
        'roles',
        'business_settings',
        'device_meta',
      ].contains(t.actualTableName),
    )) {
      if ((await _db
              .customSelect('SELECT 1 FROM "${table.actualTableName}" LIMIT 1')
              .get())
          .isNotEmpty) {
        throw StateError(
          'This device contains shop data. Use the verified Switch shop action.',
        );
      }
    }
    await prepareJoinedShop();
    await _db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('initial_join',?)",
      ['$sourceShop'],
    );
  });

  Future<void> reconcileFailedInitialJoin() =>
      exclusive(() => _undoJoinThatNeverHappened());

  /// Undoes the preparation [prepareInitialJoin] made when the server still
  /// has this device in the shop it started in as that shop's owner, i.e. the
  /// join never took effect (an expired or already-used invite code, a dropped
  /// connection). Returns whether it did. It only ever wipes a device that
  /// prepareInitialJoin found empty, so nothing is lost. Does not take the sync
  /// lock itself - callers already inside it use this directly.
  Future<bool> _undoJoinThatNeverHappened() async {
    final marker = await _db
        .customSelect(
          "SELECT value FROM local_safety_state WHERE id='initial_join'",
        )
        .getSingleOrNull();
    if (marker == null) return false;
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) return false;
    final status = await _onboarding.getClientStatus(
      baseUrl: credentials.baseUrl,
      apiKey: credentials.apiKey,
    );
    if ('${status.shopId}' != marker.data['value'] || !status.isOwner) {
      return false;
    }
    await _db.transaction(() async {
      await _db.resetForFreshStart();
      await _db.customStatement(
        "DELETE FROM local_safety_state WHERE id IN ('initial_join','shop_hydration')",
      );
    });
    return true;
  }

  Future<void>? _syncInFlight;

  /// True only while the routine push/pull of a cycle is running (not while
  /// joining or downloading a shop's first snapshot).
  bool _steadyStateNetwork = false;

  Future<void> runSyncCycle() => _syncInFlight ??= _reachableSyncCycle()
      .whenComplete(() => _syncInFlight = null);

  /// A cloud cycle that cannot possibly work (no route to the server) is not
  /// started: it would hold the exclusive queue - which changes arriving over the
  /// LAN also wait in - for as long as its request took to fail.
  Future<void> _reachableSyncCycle() async {
    final reachable = isReachable;
    if (reachable != null) {
      final credentials = await _credentials.load();
      if (credentials.isConfigured && !await reachable(credentials.baseUrl)) {
        lastError =
            'Offline. Changes remain on this device until the next successful sync.';
        return;
      }
    }
    await _runSyncCycle();
  }

  Future<void> _runSyncCycle() => exclusive(() async {
    if (canSync != null && !await canSync!()) {
      // A join that failed before it took effect leaves this device holding a
      // "waiting for the shop's data" marker with neither a license nor a shop
      // membership. Syncing is refused for such a device, so the cleanup
      // further down would never run and the join screen would sit here
      // forever. Undo the abandoned join now, while nothing has been lost.
      // Best effort: offline, or a server error, just leaves things as they are
      // for the next try.
      try {
        await _undoJoinThatNeverHappened();
      } catch (_) {}
      lastError = 'Activate this device or reconnect to its invited shop before syncing.';
      return;
    }
    if (await hasPendingShopChange) {
      lastError =
          'Shop change interrupted. Resolve it in Device Sync before syncing.';
      return;
    }
    final credentials = await _credentials.load();
    if (!credentials.isConfigured) return;

    lastError = null;
    var setAside = false;
    // A device still catching up on its very first shop download retries this
    // whole cycle every hydratingSyncRetryInterval (see app.dart's
    // _scheduleNextSync) until it finishes. Emitting this generic message here
    // unconditionally reset the visible progress to 0/indeterminate at the
    // start of EVERY one of those retries, for however long it took the reads
    // just below (and, for the one cycle right after a fresh invite-code join,
    // a real network round trip - see the initialJoin block) to get back to
    // pullInitialSnapshot's own _progress call with the real, already-persisted
    // numbers - visible as the download screen flashing back to zero and
    // climbing again every few seconds instead of just climbing. A device NOT
    // mid-hydration has no such screen watching this value, so leaving it be
    // there changes nothing.
    if (!await needsInitialPull) {
      _progress('Checking shop membership');
    }
    try {
      final initialJoin = await _db
          .customSelect(
            "SELECT value FROM local_safety_state WHERE id='initial_join'",
          )
          .getSingleOrNull();
      if (initialJoin != null) {
        final status = await _onboarding.getClientStatus(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
        );
        if (status.shopId <= 0) {
          throw StateError('The server did not return shop membership.');
        }
        await _db.transaction(() async {
          if ('${status.shopId}' == initialJoin.data['value']) {
            await _db.resetForFreshStart();
            await _db.customStatement(
              "DELETE FROM local_safety_state WHERE id='shop_hydration'",
            );
          }
          await _db.customStatement(
            "DELETE FROM local_safety_state WHERE id='initial_join'",
          );
        });
      }
      if (await needsInitialPull) {
        await pullInitialSnapshot(credentials.baseUrl, credentials.apiKey);
        await pullRemoteChanges(credentials.baseUrl, credentials.apiKey);
        final users = await _db.select(_db.users).get();
        final settings = await _db.select(_db.businessSettings).get();
        if (!users.any((u) => u.status == 'active') || settings.isEmpty) {
          throw const PaystackException(
            'Waiting for the joined shop users and settings. Sync the owner device, then retry here.',
          );
        }
        await _db.customStatement(
          "DELETE FROM local_safety_state WHERE id='shop_hydration'",
        );
      }
      // The steady-state exchange. Only THIS part may be set aside for a LAN change
      // (see applyLanChanges): joining a shop and the first download must run to
      // the end, so they never count.
      _steadyStateNetwork = true;
      try {
        await pushLocalChanges(credentials.baseUrl, credentials.apiKey);
        await pullRemoteChanges(credentials.baseUrl, credentials.apiKey);
      } finally {
        _steadyStateNetwork = false;
      }
      lastError = null;
      lastSuccess = DateTime.now();
      try {
        await _persistLastSuccess();
      } on Object {
        // Bookkeeping for the dashboard warning only - never fail a sync over it.
      }
    } on SyncRequestAbandoned {
      // A change from another device on the LAN took priority. Not an error and
      // not "offline": the cycle just runs again on its next turn.
      lastError = null;
      setAside = true;
    } on PaystackOfflineException catch (e) {
      lastError = e.timedOut
          ? 'The server is slow to answer right now, so this is taking longer. '
                'It keeps trying by itself - the first download of a shop with a '
                'long history can take a few minutes.'
          : 'Offline. Changes remain on this device until the next successful sync.';
      // No internet right now (or a slow server) - try again next cycle.
    } on PaystackException catch (e) {
      lastError = e.message;
      // Backend rejected something (not yet joined a shop, bad key,
      // ...) - try again next cycle rather than surfacing an error from
      // a background process the user didn't explicitly trigger.
    } catch (_) {
      lastError = 'Sync could not complete. Local data is retained; retry from Device Sync.';
    } finally {
      _progress(
        lastError ?? (setAside ? 'Sync will continue in a moment' : 'Sync complete'),
        completed: progress.value.completed,
        total: progress.value.total,
        busy: false,
      );
    }
  });

  /// Stage every page before applying it: the winning version of a parent
  /// can have a later change ID than a child. One deferred-FK transaction
  /// commits the complete dataset and cursor together, never half a snapshot.
  Future<void> pullInitialSnapshot(String baseUrl, String apiKey) async {
    if (!await needsInitialPull) {
      throw StateError('Snapshots are only for initial shop sync.');
    }
    await _db.customStatement(
      'CREATE TABLE IF NOT EXISTS local_sync_snapshot (id INTEGER PRIMARY KEY, record TEXT NOT NULL)',
    );
    final stored = await _db
        .customSelect(
          "SELECT value FROM local_safety_state WHERE id='sync_snapshot'",
        )
        .getSingleOrNull();
    Map<String, dynamic> state;
    if (stored == null) {
      // Explicit 0/null, unlike most _progress calls: this really is the
      // start of counting from nothing for THIS download, so any number
      // left over from whatever this device did before joining this shop
      // must not carry over and be shown as if it already applied here.
      _progress('Preparing shop download', completed: 0, total: null);
      final snapshot = await _gateway.startSnapshot(baseUrl, apiKey);
      state = {
        'id': snapshot.snapshotId,
        'highWater': snapshot.highWater,
        'total': snapshot.total,
        'after': 0,
        'received': 0,
      };
      await _db.transaction(() async {
        await _db.customStatement('DELETE FROM local_sync_snapshot');
        await _saveSnapshotState(state);
      });
    } else {
      state =
          jsonDecode(stored.data['value'] as String) as Map<String, dynamic>;
    }
    final id = state['id'] as String;
    final total = state['total'] as int;
    final highWater = state['highWater'] as int;
    if (total < 0 || highWater < 0) {
      throw StateError('Invalid snapshot metadata.');
    }
    try {
      while (state['finished'] != true) {
        _progress(
          'Downloading shop records',
          completed: state['received'] as int,
          total: total,
        );
        final snapshot = await _gateway.pullSnapshot(
          baseUrl,
          apiKey,
          id,
          state['after'] as int,
        );
        final page = snapshot.page;
        if (snapshot.snapshotId != id ||
            snapshot.highWater != highWater ||
            snapshot.total != total ||
            page.nextCursor < (state['after'] as int) ||
            page.nextCursor > highWater ||
            (page.changes.isEmpty && page.hasMore) ||
            (page.changes.isNotEmpty &&
                page.nextCursor <= (state['after'] as int))) {
          throw StateError('Invalid snapshot page.');
        }
        var previous = state['after'] as int;
        await _db.transaction(() async {
          for (final change in page.changes) {
            if (change.id <= previous ||
                change.id > page.nextCursor ||
                !syncTableAdapters.containsKey(change.tableName) ||
                change.payload['id'] != change.rowId) {
              throw StateError('Invalid snapshot record.');
            }
            previous = change.id;
            await _db.customStatement(
              'INSERT INTO local_sync_snapshot(id, record) VALUES (?, ?)',
              [
                change.id,
                jsonEncode({
                  'table': change.tableName,
                  'row': change.rowId,
                  'payload': change.payload,
                }),
              ],
            );
          }
          state = {
            ...state,
            'after': page.nextCursor,
            'received': (state['received'] as int) + page.changes.length,
            'finished': !page.hasMore,
          };
          if ((state['received'] as int) > total) {
            throw StateError('Invalid snapshot size.');
          }
          await _saveSnapshotState(state);
        });
      }
      final rows = await _db
          .customSelect(
            'SELECT id, record FROM local_sync_snapshot ORDER BY id',
          )
          .get();
      if (rows.length != total || state['received'] != total) {
        throw StateError('Incomplete snapshot.');
      }
      // completed: total, not 0 - every one of these records is already fully
      // downloaded (the checks just above prove it), so showing "0 of N" here
      // reads as having lost the download that just finished, right before
      // this method returns and the device is done. The counter below tracks
      // a genuinely different, real amount of remaining work (applying each
      // record to the local database), which is why it still climbs from
      // there for a big enough shop, unlike the pure regression this was.
      _progress('Applying shop records', completed: total, total: total);
      await _db.transaction(() async {
        await _db.customStatement('PRAGMA defer_foreign_keys=ON');
        var applied = 0;
        final products = <String>{};
        for (final row in rows) {
          final record =
              jsonDecode(row.data['record'] as String) as Map<String, dynamic>;
          final table = record['table'] as String;
          final payload = (record['payload'] as Map).cast<String, dynamic>();
          final adapter = syncTableAdapters[table]!;
          if (adapter.isAppendOnly) {
            await adapter.applyPayload(_db, payload);
          } else {
            await _applyWithLastWriteWins(
              adapter,
              PulledChange(
                id: row.data['id'] as int,
                tableName: table,
                rowId: record['row'] as String,
                payload: payload,
              ),
            );
          }
          if (table == 'products') products.add(record['row'] as String);
          if (table == 'stock_movements') {
            products.add(payload['productId'] as String);
          }
          applied++;
          if (applied % 100 == 0 || applied == total) {
            _progress(
              'Applying shop records',
              completed: applied,
              total: total,
            );
          }
        }
        await _recomputeStockQty(products);
        final users = await _db.select(_db.users).get();
        final settings = await _db.select(_db.businessSettings).get();
        if (!users.any((u) => u.status == 'active') || settings.isEmpty) {
          throw const PaystackException(
            'Waiting for the joined shop users and settings. Sync the owner device, then retry here.',
            statusCode: 409,
          );
        }
        await _syncMeta.setLastPulledChangeId(highWater);
        await _db.customStatement(
          "DELETE FROM local_safety_state WHERE id IN ('sync_snapshot','shop_hydration')",
        );
        await _db.customStatement('DELETE FROM local_sync_snapshot');
      });
      // Cleanup failure must never undo a committed local snapshot.
      try {
        await _gateway.discardSnapshot(baseUrl, apiKey, id);
      } catch (_) {}
    } on PaystackException catch (e) {
      if (e.statusCode == 410 || e.statusCode == 409) {
        if (e.statusCode == 409) {
          await _gateway.discardSnapshot(baseUrl, apiKey, id);
        }
        await _db.transaction(() async {
          await _db.customStatement('DELETE FROM local_sync_snapshot');
          await _db.customStatement(
            "DELETE FROM local_safety_state WHERE id='sync_snapshot'",
          );
        });
      }
      rethrow;
    }
  }

  Future<void> _saveSnapshotState(Map<String, dynamic> state) =>
      _db.customStatement(
        "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('sync_snapshot',?)",
        [jsonEncode(state)],
      );

  /// Gathers pending rows across ALL synced tables before sending -
  /// correctness-critical, not stylistic. local_rev is one counter
  /// shared across every table on this device, so a parent row (e.g. a
  /// category) always has a lower rev than a child that references it
  /// (e.g. a product); a per-table push loop could send them out of
  /// that order and violate the invariant every other device's pull
  /// relies on to never see a child before its parent.
  /// How many extra requests one cycle may spend isolating rejected rows, and
  /// how many rows in all may be set aside: a server that is refusing
  /// EVERYTHING (its clock, a bad deploy) must not make the app quietly set
  /// aside a whole shop's data one row at a time.
  static const _isolationRequestsPerCycle = 120;
  static const _quarantineCycleLimit = 25;
  static const _quarantineTotalLimit = 500;

  List<Map<String, dynamic>> _batchOf(List<_PendingChange> slice) => slice
      .map(
        (change) => {
          'table_name': change.tableName,
          'row_id': change.json['id'],
          'local_rev': change.json['localRev'],
          'updated_at': change.json['updatedAt'],
          'payload': change.json,
        },
      )
      .toList();

  /// The server answers a batch all-or-nothing (one bad row rolls back the other
  /// 199), and this device used to retry that same batch forever - so one row
  /// the server refused kept every later row of the shop, thousands of sales,
  /// off the cloud without a word. Now a refused batch is split until the
  /// offending row is found; that row is set aside (and shown to the person),
  /// and everything else goes through. Only a refusal that names a validation
  /// reason counts: offline, 5xx and the server's generic "Could not record
  /// changes." (which a momentary database hiccup also produces) are retried
  /// as before and never cost a row its place.
  Future<void> _pushResolving(
    String baseUrl,
    String apiKey,
    List<_PendingChange> slice,
    _Isolation isolation,
  ) async {
    try {
      await _gateway.pushChanges(
        baseUrl: baseUrl,
        apiKey: apiKey,
        changes: _batchOf(slice),
      );
      await _syncMeta.setLastPushedLocalRev(slice.last.json['localRev'] as int);
    } on PaystackException catch (error) {
      if (!_isValidationRefusal(error)) rethrow;
      if (slice.length == 1) {
        if (!await _canQuarantineMore(isolation)) rethrow;
        await _quarantine(slice.single, error.message);
        isolation.quarantinedThisCycle++;
        await _syncMeta.setLastPushedLocalRev(
          slice.single.json['localRev'] as int,
        );
        return;
      }
      if (isolation.requestsLeft <= 0) rethrow;
      isolation.requestsLeft--;
      final middle = slice.length ~/ 2;
      await _pushResolving(baseUrl, apiKey, slice.sublist(0, middle), isolation);
      await _pushResolving(baseUrl, apiKey, slice.sublist(middle), isolation);
    }
  }

  static const _refusalPrefix = 'Could not record changes: ';

  static bool _isValidationRefusal(PaystackException error) =>
      error.statusCode == 422 && error.message.startsWith(_refusalPrefix);

  Future<bool> _canQuarantineMore(_Isolation isolation) async {
    if (isolation.quarantinedThisCycle >= _quarantineCycleLimit) return false;
    return await quarantinedCount() < _quarantineTotalLimit;
  }

  Future<void> _ensureQuarantineTable() => _db.customStatement(
    'CREATE TABLE IF NOT EXISTS local_sync_quarantine ('
    'table_name TEXT NOT NULL, row_id TEXT NOT NULL, local_rev INTEGER NOT NULL, '
    'reason TEXT NOT NULL, quarantined_at TEXT NOT NULL, '
    'PRIMARY KEY(table_name, row_id, local_rev))',
  );

  Future<void> _quarantine(_PendingChange change, String reason) async {
    await _ensureQuarantineTable();
    final cleaned = reason.startsWith(_refusalPrefix)
        ? reason.substring(_refusalPrefix.length)
        : reason;
    await _db.customStatement(
      'INSERT OR REPLACE INTO local_sync_quarantine'
      '(table_name, row_id, local_rev, reason, quarantined_at) VALUES (?, ?, ?, ?, ?)',
      [
        change.tableName,
        change.json['id'] as String,
        change.json['localRev'] as int,
        cleaned,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  /// Rows the shop server refused for a reason of their own, set aside here so
  /// the rest could be uploaded. They are still on this device and in its backups.
  Future<int> quarantinedCount() async {
    await _ensureQuarantineTable();
    final row = await _db
        .customSelect('SELECT COUNT(*) AS n FROM local_sync_quarantine')
        .getSingle();
    return row.read<int>('n');
  }

  /// The set-aside rows grouped by table and reason, biggest group first.
  Future<List<QuarantineGroup>> quarantineGroups() async {
    await _ensureQuarantineTable();
    final rows = await _db
        .customSelect(
          'SELECT table_name, reason, COUNT(*) AS n FROM local_sync_quarantine '
          'GROUP BY table_name, reason ORDER BY n DESC, table_name',
        )
        .get();
    return [
      for (final row in rows)
        QuarantineGroup(
          row.read<String>('table_name'),
          row.read<String>('reason'),
          row.read<int>('n'),
        ),
    ];
  }

  /// How long a set-aside row waits before the server is asked about it again.
  static const quarantineRetryAfter = Duration(hours: 3);
  static const _quarantineRetryRows = 25;

  Future<void> _forgetQuarantined(String tableName, String rowId, int localRev) =>
      _db.customStatement(
        'DELETE FROM local_sync_quarantine '
        'WHERE table_name = ? AND row_id = ? AND local_rev = ?',
        [tableName, rowId, localRev],
      );

  /// Gives rows the server once refused another chance. A refusal is often
  /// temporary - the server was fixed, the device's clock was corrected - and a
  /// set-aside row is otherwise never looked at again, so the dashboard warning
  /// about it would stay for good. Each row is retried at most every
  /// [quarantineRetryAfter]; accepted rows leave the set-aside list, rows still
  /// refused stay in it. This never moves the upload cursor: these rows are older
  /// than it. A row edited since (it then has a newer revision that uploads on
  /// its own) or no longer present is simply dropped from the list.
  Future<void> retryQuarantined(
    String baseUrl,
    String apiKey, {
    bool force = false,
  }) async {
    await _ensureQuarantineTable();
    final cutoff = force
        ? '9999'
        : DateTime.now().toUtc().subtract(quarantineRetryAfter).toIso8601String();
    final due = await _db
        .customSelect(
          'SELECT table_name, row_id, local_rev FROM local_sync_quarantine '
          'WHERE quarantined_at <= ? ORDER BY local_rev LIMIT ?',
          variables: [
            Variable<String>(cutoff),
            Variable<int>(_quarantineRetryRows),
          ],
        )
        .get();
    if (due.isEmpty) return;

    final deviceId = await _syncMeta.deviceId();
    final byTable = <String, List<({String id, int rev})>>{};
    for (final row in due) {
      byTable
          .putIfAbsent(row.read<String>('table_name'), () => [])
          .add((id: row.read<String>('row_id'), rev: row.read<int>('local_rev')));
    }
    final retry = <_PendingChange>[];
    for (final entry in byTable.entries) {
      final adapter = syncTableAdapters[entry.key];
      if (adapter == null) {
        for (final item in entry.value) {
          await _forgetQuarantined(entry.key, item.id, item.rev);
        }
        continue;
      }
      var lowest = entry.value.first.rev;
      for (final item in entry.value) {
        if (item.rev < lowest) lowest = item.rev;
      }
      final rows = await adapter.pendingRowsJson(_db, deviceId, lowest - 1);
      final current = {
        for (final json in rows) '${json['id']}@${json['localRev']}': json,
      };
      for (final item in entry.value) {
        final json = current['${item.id}@${item.rev}'];
        if (json == null) {
          await _forgetQuarantined(entry.key, item.id, item.rev);
        } else {
          retry.add(_PendingChange(entry.key, json));
        }
      }
    }
    retry.sort(
      (a, b) =>
          (a.json['localRev'] as int).compareTo(b.json['localRev'] as int),
    );
    await _retryResolving(
      baseUrl,
      apiKey,
      retry,
      _Isolation(_isolationRequestsPerCycle),
    );
  }

  Future<void> _retryResolving(
    String baseUrl,
    String apiKey,
    List<_PendingChange> slice,
    _Isolation isolation,
  ) async {
    if (slice.isEmpty) return;
    try {
      await _gateway.pushChanges(
        baseUrl: baseUrl,
        apiKey: apiKey,
        changes: _batchOf(slice),
      );
      for (final change in slice) {
        await _forgetQuarantined(
          change.tableName,
          change.json['id'] as String,
          change.json['localRev'] as int,
        );
      }
    } on PaystackException catch (error) {
      if (!_isValidationRefusal(error)) rethrow;
      if (slice.length == 1) {
        final change = slice.single;
        // Some refusals are about this exact revision of the row, not the data:
        // the server already holds a different copy of revision N, or it dated
        // the row in the future. Sending the same row again as a new revision
        // cures both, and it uploads on the next normal cycle.
        if (_restampCures(error.message) && await _restamp(change)) {
          await _forgetQuarantined(
            change.tableName,
            change.json['id'] as String,
            change.json['localRev'] as int,
          );
          return;
        }
        // Still refused: keep it, with the server's latest words and a fresh
        // clock so it is not asked about again for another few hours.
        await _quarantine(change, error.message);
        return;
      }
      if (isolation.requestsLeft <= 0) return;
      isolation.requestsLeft--;
      final middle = slice.length ~/ 2;
      await _retryResolving(baseUrl, apiKey, slice.sublist(0, middle), isolation);
      await _retryResolving(baseUrl, apiKey, slice.sublist(middle), isolation);
    }
  }

  static const _differentContentReason = 'already recorded with different content';
  static const _futureDatedReason = 'dated more than a day in the future';

  static bool _restampCures(String reason) =>
      reason.contains(_differentContentReason) || reason.contains(_futureDatedReason);

  /// Gives a set-aside row a fresh revision number and a fresh updated-at, so the
  /// server sees it as a new change instead of a clash with an old one and every
  /// other device takes it as the newest copy. The data itself is untouched. (The
  /// database stamps updated_at on any update anyway; it is set here explicitly so
  /// the value is the one this method means.)
  Future<bool> _restamp(_PendingChange change) async {
    final id = change.json['id'] as String;
    final oldRev = change.json['localRev'] as int;
    if (!syncTableAdapters.containsKey(change.tableName)) return false;
    var changed = false;
    await _db.transaction(() async {
      final rev = await _syncMeta.nextLocalRev();
      final updated = await _db.customUpdate(
        'UPDATE "${change.tableName}" SET local_rev = ?, updated_at = ? '
        'WHERE id = ? AND local_rev = ?',
        variables: [
          Variable<int>(rev),
          Variable<String>(DateTime.now().toUtc().toIso8601String()),
          Variable<String>(id),
          Variable<int>(oldRev),
        ],
      );
      changed = updated == 1;
    });
    return changed;
  }

  DateTime? _lastSuccessWrittenAt;

  Future<void> _persistLastSuccess() async {
    final now = DateTime.now().toUtc();
    final written = _lastSuccessWrittenAt;
    if (written != null && now.difference(written) < const Duration(minutes: 5)) {
      return;
    }
    _lastSuccessWrittenAt = now;
    await _db.customStatement(
      "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('last_sync_success',?)",
      [now.toIso8601String()],
    );
  }

  Future<DateTime?> _storedTime(String id) async {
    final row = await _db
        .customSelect(
          'SELECT value FROM local_safety_state WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.read<String>('value'));
  }

  /// What the dashboard needs to tell a person their data is not reaching the
  /// cloud: rows waiting to upload, rows set aside, and when an upload last worked.
  Future<SyncHealth> health() async {
    final deviceId = await _syncMeta.deviceId();
    final since = await _syncMeta.lastPushedLocalRev();
    var pending = 0;
    for (final adapter in syncTableAdapters.values) {
      final row = await _db
          .customSelect(
            'SELECT COUNT(*) AS n FROM "${adapter.tableName}" '
            'WHERE created_by_device_id = ? AND local_rev > ?',
            variables: [Variable<String>(deviceId), Variable<int>(since)],
          )
          .getSingle();
      pending += row.read<int>('n');
    }
    var baseline = await _storedTime('sync_health_baseline');
    if (baseline == null) {
      baseline = DateTime.now().toUtc();
      await _db.customStatement(
        "INSERT OR REPLACE INTO local_safety_state(id,value) VALUES('sync_health_baseline',?)",
        [baseline.toIso8601String()],
      );
    }
    return SyncHealth(
      pendingChanges: pending,
      quarantined: await quarantinedCount(),
      lastSuccess: lastSuccess ?? await _storedTime('last_sync_success'),
      baseline: baseline,
    );
  }

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
    pending.sort(
      (a, b) =>
          (a.json['localRev'] as int).compareTo(b.json['localRev'] as int),
    );

    // Bound every request so a large import cannot create an unbounded
    // JSON body on either the device or the relay server. Advance the
    // cursor after each acknowledged batch: if batch N+1 fails, the
    // next cycle safely resumes there instead of retransmitting every
    // earlier row or skipping anything that was not accepted.
    final isolation = _Isolation(_isolationRequestsPerCycle);
    for (var offset = 0; offset < pending.length; offset += _pushBatchSize) {
      final end = (offset + _pushBatchSize).clamp(0, pending.length);
      await _pushResolving(
        baseUrl,
        apiKey,
        pending.sublist(offset, end),
        isolation,
      );
    }

    // Rows set aside earlier get another chance every few hours. Best-effort
    // like the relay below: this device's new changes are already uploaded, so
    // a failure here must not make the whole upload look failed.
    try {
      await retryQuarantined(baseUrl, apiKey);
    } catch (_) {}

    // Best-effort, deliberately not awaited into a rethrow: this device's
    // OWN changes are already safely recorded on the server by this point.
    // A LAN-relayed change (received from another device over the network,
    // not this device's own data) that the server permanently refuses -
    // confirmed for real: most often because its source device has since
    // left the shop or been disabled - must never make pushLocalChanges
    // itself look like it failed, or anything that depends on it
    // succeeding (leaving a shop, in particular - see shop_safety_service's
    // requireBackup:false path) would be blocked by data that was never
    // this device's own to begin with. Retried on the next normal cycle
    // either way.
    try {
      await _pushLanRelayOutbox(baseUrl, apiKey);
    } catch (_) {}
  }

  Future<void> _ensureLanTables() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS local_lan_receipts (
        source_device_id TEXT NOT NULL,
        local_rev INTEGER NOT NULL,
        PRIMARY KEY(source_device_id, local_rev)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS local_lan_relay_outbox (
        source_device_id TEXT NOT NULL,
        local_rev INTEGER NOT NULL,
        record TEXT NOT NULL,
        PRIMARY KEY(source_device_id, local_rev)
      )
    ''');
  }

  Future<Map<String, int>> lanRevisionCursors() async {
    await _ensureLanTables();
    final cursors = <String, int>{};
    for (final adapter in syncTableAdapters.values) {
      final rows = await _db
          .customSelect(
            'SELECT created_by_device_id AS device_id, MAX(local_rev) AS revision '
            'FROM "${adapter.tableName}" GROUP BY created_by_device_id',
          )
          .get();
      for (final row in rows) {
        final source = row.data['device_id'] as String? ?? '';
        final revision = row.data['revision'] as int? ?? 0;
        if (source.isNotEmpty && revision > (cursors[source] ?? 0)) {
          cursors[source] = revision;
        }
      }
    }
    final receipts = await _db
        .customSelect(
          'SELECT source_device_id, MAX(local_rev) AS revision '
          'FROM local_lan_receipts GROUP BY source_device_id',
        )
        .get();
    for (final row in receipts) {
      final source = row.data['source_device_id'] as String;
      final revision = row.data['revision'] as int;
      if (revision > (cursors[source] ?? 0)) cursors[source] = revision;
    }
    return cursors;
  }

  /// Exports a contiguous revision prefix per source. Keeping each source in
  /// revision order makes the receiver's max-revision cursor safe even when a
  /// response is capped and resumed on the next LAN pass.
  Future<List<LanSyncChange>> exportLanChanges(
    Map<String, int> known, {
    int limit = 500,
  }) async {
    final sources = <String>{};
    for (final adapter in syncTableAdapters.values) {
      final rows = await _db
          .customSelect(
            'SELECT DISTINCT created_by_device_id AS device_id FROM "${adapter.tableName}"',
          )
          .get();
      sources.addAll(rows.map((row) => row.data['device_id'] as String));
    }

    final bySource = <String, List<LanSyncChange>>{};
    for (final source in sources.where((value) => value.isNotEmpty)) {
      final changes = <LanSyncChange>[];
      final since = known[source] ?? 0;
      for (final adapter in syncTableAdapters.values) {
        for (final payload in await adapter.pendingRowsJson(
          _db,
          source,
          since,
        )) {
          changes.add(
            LanSyncChange(
              sourceDeviceId: source,
              tableName: adapter.tableName,
              rowId: payload['id'] as String,
              localRev: payload['localRev'] as int,
              updatedAt: payload['updatedAt'] as String,
              payload: payload,
            ),
          );
        }
      }
      changes.sort((a, b) => a.localRev.compareTo(b.localRev));
      if (changes.isNotEmpty) bySource[source] = changes;
    }

    final result = <LanSyncChange>[];
    for (final source in bySource.keys.toList()..sort()) {
      for (final change in bySource[source]!) {
        if (result.length == limit) return result;
        result.add(change);
      }
    }
    return result;
  }

  Future<void> applyLanChanges(List<LanSyncChange> changes) {
    // Nothing to apply needs no place in the queue (a pull that found the peer
    // had nothing new used to wait behind a cloud cycle just to do nothing).
    if (changes.isEmpty) return Future<void>.value();
    // A cloud cycle that is waiting on the server would keep this change
    // queued behind it for as long as the request lasts (up to a minute on a slow
    // route). Ask it to step aside instead - it runs again on its next turn.
    final setAside = _steadyStateNetwork;
    if (setAside) _gateway.holdRequests();
    return _applyLanChanges(changes).whenComplete(() {
      if (setAside) _gateway.releaseRequests();
    });
  }

  Future<void> _applyLanChanges(List<LanSyncChange> changes) => exclusive(
    () async {
      if (changes.isEmpty) return;
      await _ensureLanTables();
      final ownDeviceId = await _syncMeta.deviceId();
      final touchedProducts = <String>{};
      await _db.transaction(() async {
        await _db.customStatement('PRAGMA defer_foreign_keys=ON');
        for (final change in changes) {
          final adapter = syncTableAdapters[change.tableName];
          if (adapter == null ||
              change.sourceDeviceId.isEmpty ||
              change.rowId.isEmpty ||
              change.localRev < 1 ||
              change.payload['id'] != change.rowId ||
              change.payload['localRev'] != change.localRev ||
              change.payload['updatedAt'] != change.updatedAt ||
              change.payload['createdByDeviceId'] != change.sourceDeviceId) {
            throw StateError('Invalid LAN sync change.');
          }
          final seen = await _db
              .customSelect(
                'SELECT 1 FROM local_lan_receipts WHERE source_device_id = ? AND local_rev = ?',
                variables: [
                  Variable(change.sourceDeviceId),
                  Variable(change.localRev),
                ],
              )
              .getSingleOrNull();
          if (seen != null) continue;

          if (adapter.isAppendOnly) {
            await adapter.applyPayload(_db, change.payload);
          } else {
            await _applyWithLastWriteWins(
              adapter,
              PulledChange(
                id: 0,
                tableName: change.tableName,
                rowId: change.rowId,
                payload: change.payload,
              ),
            );
          }
          if (change.tableName == 'products') touchedProducts.add(change.rowId);
          if (change.tableName == 'stock_movements') {
            final productId = change.payload['productId'] as String?;
            if (productId != null && productId.isNotEmpty) {
              touchedProducts.add(productId);
            }
          }
          await _db.customStatement(
            'INSERT INTO local_lan_receipts(source_device_id, local_rev) VALUES(?, ?)',
            [change.sourceDeviceId, change.localRev],
          );
          if (change.sourceDeviceId != ownDeviceId) {
            await _db.customStatement(
              'INSERT OR IGNORE INTO local_lan_relay_outbox(source_device_id, local_rev, record) VALUES(?, ?, ?)',
              [
                change.sourceDeviceId,
                change.localRev,
                jsonEncode(change.toJson()),
              ],
            );
          }
        }
        await _recomputeStockQty(touchedProducts);
      });
    },
  );

  Future<void> _deleteRelayOutboxRows(Iterable<int> rowIds) async {
    final ids = rowIds.toList();
    if (ids.isEmpty) return;
    await _db.customStatement(
      'DELETE FROM local_lan_relay_outbox WHERE rowid IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
  }

  List<Map<String, dynamic>> _relayChangesOf(Iterable<QueryRow> rows) => rows
      .map(
        (row) => (jsonDecode(row.data['record'] as String) as Map)
            .cast<String, dynamic>(),
      )
      .toList();

  Future<void> _pushLanRelayOutbox(String baseUrl, String apiKey) async {
    await _ensureLanTables();
    while (true) {
      final rows = await _db
          .customSelect(
            'SELECT rowid, source_device_id, record FROM local_lan_relay_outbox ORDER BY rowid LIMIT $_pushBatchSize',
          )
          .get();
      if (rows.isEmpty) return;
      try {
        await _gateway.pushChanges(
          baseUrl: baseUrl,
          apiKey: apiKey,
          changes: _relayChangesOf(rows),
        );
        await _deleteRelayOutboxRows(
          rows.map((row) => row.data['rowid'] as int),
        );
        continue;
      } on PaystackException catch (e) {
        if (e.statusCode != 422) rethrow;
      }
      // Whether the server accepts a relayed change depends on its SOURCE
      // device (is it still an active client of this shop?), a single
      // fact shared by every row from that source - never a fact about
      // an individual row. Retrying per row here previously meant a
      // source inactive for a while, with hundreds of rows queued up
      // after days of testing, cost one HTTP round trip PER ROW to
      // rediscover the same fact hundreds of times - easily minutes, and
      // exactly what made leaving a shop on a device with such a backlog
      // look permanently stuck. Grouping by source bounds this to one
      // extra request per DISTINCT source device instead - typically a
      // handful, never hundreds.
      final bySource = <String, List<QueryRow>>{};
      for (final row in rows) {
        (bySource[row.data['source_device_id'] as String] ??= []).add(row);
      }
      if (bySource.length == 1) {
        // The whole batch was already this one source and we just learned
        // it's rejected - no need to ask again. Drop every row queued for
        // it, not just this LIMIT-sized slice, so a large backlog clears
        // in this one extra request instead of being rediscovered (and
        // paid for again) batch after batch.
        await _db.customStatement(
          'DELETE FROM local_lan_relay_outbox WHERE source_device_id = ?',
          [bySource.keys.single],
        );
        continue;
      }
      for (final group in bySource.values) {
        try {
          await _gateway.pushChanges(
            baseUrl: baseUrl,
            apiKey: apiKey,
            changes: _relayChangesOf(group),
          );
          await _deleteRelayOutboxRows(
            group.map((row) => row.data['rowid'] as int),
          );
        } on PaystackException catch (single) {
          if (single.statusCode != 422) rethrow;
          await _db.customStatement(
            'DELETE FROM local_lan_relay_outbox WHERE source_device_id = ?',
            [group.first.data['source_device_id'] as String],
          );
        }
      }
    }
  }

  /// Pages through pull_changes in ascending id order, applying each
  /// page inside its own transaction. A correctly-behaving push never
  /// produces a child-before-parent ordering (see pushLocalChanges), so
  /// PRAGMA defer_foreign_keys is defense in depth for the
  /// should-be-impossible case, not the primary mechanism.
  Future<void> pullRemoteChanges(String baseUrl, String apiKey) async {
    var cursor = await _syncMeta.lastPulledChangeId();
    final touchedProductIds = <String>{};
    var received = 0;
    _progress('Checking newer shop changes');

    while (true) {
      final result = await _gateway.pullChanges(
        baseUrl: baseUrl,
        apiKey: apiKey,
        since: cursor,
      );
      if (result.nextCursor < cursor ||
          (result.changes.isNotEmpty && result.nextCursor <= cursor) ||
          (result.changes.isEmpty && result.hasMore)) {
        throw StateError('The server returned an invalid sync cursor.');
      }
      if (result.changes.isEmpty) break;

      await _db.transaction(() async {
        touchedProductIds.clear();
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
            if (productId != null && productId.isNotEmpty) {
              touchedProductIds.add(productId);
            }
          }
        }
        await _recomputeStockQty(touchedProductIds);
        await _syncMeta.setLastPulledChangeId(result.nextCursor);
      });

      cursor = result.nextCursor;
      received += result.changes.length;
      _progress('Receiving newer shop changes', completed: received);
      if (!result.hasMore) break;
    }
  }

  Future<void> _applyWithLastWriteWins(
    SyncTableAdapter adapter,
    PulledChange change,
  ) async {
    final incomingUpdatedAt = change.payload['updatedAt'] as String? ?? '';
    final incomingDeviceId =
        change.payload['createdByDeviceId'] as String? ?? '';
    final existing = await adapter.findLocalMeta!(_db, change.rowId);

    // No local copy yet (first time this device has seen the row), or
    // the incoming version is strictly newer, or an exact updated_at
    // tie broken deterministically by device_id - the goal isn't
    // objectively picking the "correct" winner (impossible under wall-
    // clock skew), it's guaranteeing every device converges on the same
    // answer rather than two devices permanently disagreeing.
    final shouldApply =
        existing == null ||
        incomingUpdatedAt.compareTo(existing.updatedAt) > 0 ||
        (incomingUpdatedAt == existing.updatedAt &&
            incomingDeviceId.compareTo(existing.deviceId) > 0);

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
