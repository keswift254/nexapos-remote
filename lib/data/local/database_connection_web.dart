import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'database_encryption_key.dart';

/// Real web implementation, using drift's WASM database stack. Selected
/// on web by database.dart's conditional import.
///
/// Deliberately probes storage implementations and picks one by hand
/// instead of calling the simpler WasmDatabase.open() (which auto-picks
/// the "best" option) - confirmed for real, this session, that
/// WasmDatabase.open()'s default choice here is
/// WasmStorageImplementation.sharedIndexedDb, which routes every query
/// through drift's SharedWorker. In that mode, the very first real query
/// after opening (e.g. SyncService.needsInitialPull) reliably fails with
/// a bare "TypeError: Failed to fetch" and no further detail - reproduced
/// consistently across multiple fresh origins/rebuilds, while manually
/// replaying drift's own worker protocol by hand against the same
/// SharedWorker succeeded, and while the dedicated-worker-backed
/// WasmStorageImplementation.unsafeIndexedDb (forced below) works
/// perfectly. Root cause not fully isolated (something specific to
/// SharedWorker-hosted query serving, possibly an artifact of this
/// project's test environment rather than every browser) - but avoiding
/// the SharedWorker-hosted implementations entirely is a safe, deliberate
/// choice either way: this app's web sessions are single-tab POS
/// terminals, so the cross-tab query broadcasting sharedIndexedDb/
/// opfsShared exist for isn't something this app needs to give up
/// anything for. See WasmStorageImplementation's own doc comments for
/// which implementations are dedicated-worker-backed
/// (opfsLocks/unsafeIndexedDb, preferred here) vs SharedWorker-backed
/// (opfsShared/sharedIndexedDb, deliberately skipped).
///
/// SECURITY NOTE, deliberately not silently glossed over: unlike native
/// (SQLCipher-style PRAGMA key encryption via DriftNativeOptions.setup),
/// this does NOT encrypt the local database yet. The spike found that
/// sqlite3mc's PRAGMA key fails with "Encryption is not supported by
/// the VFS" against whatever storage backend gets auto-selected without
/// OPFS - and OPFS itself needs the hosting page to be served with
/// Cross-Origin-Opener-Policy/Cross-Origin-Embedder-Policy headers (see
/// the browser-POS plan's Hosting section - GitHub Pages can't set
/// those, a host that can may be needed). Getting a real device/shop
/// api_key persisted via secureStorageProvider (which does have a real
/// encrypted web backend, flutter_secure_storage_web) was the priority
/// for this pass; encrypting the synced business-data copy itself is a
/// known, tracked gap to close before this ships for real use, not an
/// oversight. sqlite3Uri points at sqlite3mc.wasm (not plain
/// sqlite3.wasm) specifically so turning encryption back on later is a
/// pure code change here, not a new asset.
DatabaseConnection openConnection() {
  return DatabaseConnection.delayed(
    Future(() async {
      // Resolves/creates the same encryption key native uses - kept
      // even though it's unused for now (see the security note above),
      // so a future version that re-enables PRAGMA key here doesn't
      // orphan whatever key a device already generated, and so the key
      // exists ready to use the moment OPFS/headers make it viable.
      const storage = FlutterSecureStorage();
      await getOrCreateEncryptionKey(storage);

      final probed = await WasmDatabase.probe(
        sqlite3Uri: Uri.parse('sqlite3mc.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
        databaseName: 'nexapos',
      );

      const dedicatedWorkerImplementations = [
        WasmStorageImplementation.opfsLocks,
        WasmStorageImplementation.unsafeIndexedDb,
      ];
      final available = probed.availableStorages;
      final implementation = dedicatedWorkerImplementations.firstWhere(
        available.contains,
        orElse: () => available.first,
      );

      return probed.open(implementation, 'nexapos');
    }),
  );
}
