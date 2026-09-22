import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Variable;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../data/local/database.dart';
import '../../data/local/sync_metadata.dart';
import '../../data/sync/platform_sync_gateway.dart';
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
  );
}

class _PendingChange {
  final String tableName;
  final Map<String, dynamic> json;
  const _PendingChange(this.tableName, this.json);
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

  SyncService(
    this._db,
    this._syncMeta,
    this._gateway,
    this._credentials, {
    PlatformOnboardingGateway? onboarding,
    this.canSync,
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

  Future<void> runSyncCycle() => _syncInFlight ??= _runSyncCycle().whenComplete(
    () => _syncInFlight = null,
  );

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
      await pushLocalChanges(credentials.baseUrl, credentials.apiKey);
      await pullRemoteChanges(credentials.baseUrl, credentials.apiKey);
      lastError = null;
      lastSuccess = DateTime.now();
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
        lastError ?? 'Sync complete',
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
    for (var offset = 0; offset < pending.length; offset += _pushBatchSize) {
      final end = (offset + _pushBatchSize).clamp(0, pending.length);
      final slice = pending.sublist(offset, end);
      final batch = slice
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

      await _gateway.pushChanges(
        baseUrl: baseUrl,
        apiKey: apiKey,
        changes: batch,
      );
      await _syncMeta.setLastPushedLocalRev(slice.last.json['localRev'] as int);
    }

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

  Future<void> applyLanChanges(List<LanSyncChange> changes) => exclusive(
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

  Future<void> _pushLanRelayOutbox(String baseUrl, String apiKey) async {
    await _ensureLanTables();
    while (true) {
      final rows = await _db
          .customSelect(
            'SELECT rowid, record FROM local_lan_relay_outbox ORDER BY rowid LIMIT $_pushBatchSize',
          )
          .get();
      if (rows.isEmpty) return;
      final changes = rows.map((row) {
        return (jsonDecode(row.data['record'] as String) as Map)
            .cast<String, dynamic>();
      }).toList();
      try {
        await _gateway.pushChanges(
          baseUrl: baseUrl,
          apiKey: apiKey,
          changes: changes,
        );
        await _deleteRelayOutboxRows(
          rows.map((row) => row.data['rowid'] as int),
        );
      } on PaystackException catch (e) {
        if (e.statusCode != 422) rethrow;
        if (rows.length == 1) {
          // Already know exactly which single change was rejected - no
          // need to resend it just to learn that again. Permanently drop
          // it: it came from a peer device, not this one, so dropping it
          // loses nothing this device made.
          await _deleteRelayOutboxRows([rows.single.data['rowid'] as int]);
          continue;
        }
        // The server rejects one bad entry's whole batch (see push_changes),
        // even when only one relayed change out of many is actually invalid
        // - most often because its source device has since left the shop or
        // been disabled. Retry one row at a time so the rest of the batch
        // still gets through, and permanently drop only the one the server
        // genuinely never accepts on its own.
        for (final row in rows) {
          final rowId = row.data['rowid'] as int;
          final change = (jsonDecode(row.data['record'] as String) as Map)
              .cast<String, dynamic>();
          try {
            await _gateway.pushChanges(
              baseUrl: baseUrl,
              apiKey: apiKey,
              changes: [change],
            );
          } on PaystackException catch (single) {
            if (single.statusCode != 422) rethrow;
          }
          await _deleteRelayOutboxRows([rowId]);
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
