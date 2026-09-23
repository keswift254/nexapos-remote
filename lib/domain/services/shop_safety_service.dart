import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/import/shop_archive.dart';
import '../../data/local/database.dart';
import '../../data/payments/platform_onboarding_gateway.dart';
import '../entities/paystack_credentials.dart';
import 'sensitive_action_service.dart';
import 'sync_service.dart';
import 'license_service.dart';
import 'session_service.dart';
import 'pending_sales_notifier.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../features/checkout/cart_notifier.dart';

final shopSafetyProvider = Provider<ShopSafetyService>(
  (ref) => ShopSafetyService(
    ref.watch(appDatabaseProvider),
    ref.watch(syncServiceProvider),
    ref.watch(sensitiveActionProvider),
    ref.watch(platformOnboardingGatewayProvider),
    onShopChanged: (joining) async {
      final license = ref.read(licenseServiceProvider);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(pendingPaystackSalesProvider);
      ref.invalidate(userRepositoryProvider);
      await ref.read(sessionProvider.notifier).logout();
      if (joining) {
        await license.confirmJoinedMembership();
      } else {
        await license.clearJoinedMembership();
      }
    },
  ),
);

typedef SaveRecovery = Future<bool> Function(ShopArchive archive);

class ShopSafetyService {
  final AppDatabase db;
  final SyncService sync;
  final SensitiveActionService security;
  final PlatformOnboardingGateway gateway;
  final Future<void> Function(bool joining)? onShopChanged;
  final Duration retryDelay;
  ShopSafetyService(
    this.db,
    this.sync,
    this.security,
    this.gateway, {
    this.onShopChanged,
    this.retryDelay = const Duration(seconds: 3),
  });

  Future<bool> changeShop({
    required ActionApproval approval,
    required PaystackCredentials credentials,
    required SaveRecovery saveRecovery,
    String? inviteCode,
    // False only for a joined (non-owner) device leaving its shop: its data
    // isn't unique to it - by definition it's a copy of what the shop it is
    // leaving already has - so an encrypted local backup of it is pure
    // friction, not safety. Left true for founding a shop's own encrypted
    // backup (its owner device may be the sole copy) and for switching into
    // a different shop (an inviteCode is present, a less certain case).
    bool requireBackup = true,
  }) async {
    final action = inviteCode == null ? 'Leave this shop' : 'Switch shop';
    await security.consume(approval, action);
    return sync.exclusive(() async {
      if (await sync.hasPendingShopChange) {
        throw StateError('Resolve the interrupted shop change first.');
      }
      final status = await gateway.getClientStatus(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
      );
      if (status.shopId <= 0) {
        throw StateError('Update the platform server before changing shops.');
      }
      // Persist before the remote mutation. A timeout is ambiguous, so leave
      // this journal in place until the current server membership is checked.
      await db.customStatement(
        "INSERT INTO local_safety_state(id,value) VALUES('shop_change',?)",
        [
          jsonEncode({
            'sourceShop': status.shopId,
            'joining': inviteCode != null,
          }),
        ],
      );
      try {
        if (requireBackup) {
          final archive = await ShopArchive.capture(db);
          await archive.validate();
          if (!await saveRecovery(archive)) {
            await db.customStatement(
              "DELETE FROM local_safety_state WHERE id='shop_change'",
            );
            return false;
          }
        } else {
          // Push first rather than trusting this device is already fully
          // synced - skipping the backup on a device that turns out to hold
          // an unsent sale would be real data loss, not just redundant
          // caution. A failure here (e.g. offline) is caught below like a
          // failed backup would be: nothing server-side has happened yet, so
          // the journal is simply cleared and the local data is left intact
          // to retry from - there is nothing ambiguous to resolve later.
          //
          // Retried a few times in place: the password approval above is
          // one-time-use (already consumed), so a transient failure here
          // used to fail the whole attempt and send the user all the way
          // back to re-entering their password for another try - confirmed
          // for real, a device with an occasionally slow connection needed
          // three full manual retries (three password prompts) just to
          // leave. A short automatic retry absorbs exactly that kind of
          // blip without asking for anything more than a few seconds' wait.
          await _withRetry(
            () => sync.pushLocalChanges(credentials.baseUrl, credentials.apiKey),
          );
        }
      } catch (_) {
        await db.customStatement(
          "DELETE FROM local_safety_state WHERE id='shop_change'",
        );
        rethrow;
      }
      // Same reasoning as the retry above: this is the step that actually
      // changes shop membership, and by this point the approval is spent
      // and (for the light path) the push already succeeded - a transient
      // failure here specifically must not throw the user back to square
      // one either.
      await _withRetry(() => inviteCode == null
          ? gateway.leaveShop(
              baseUrl: credentials.baseUrl,
              apiKey: credentials.apiKey,
            )
          : gateway.joinShop(
              baseUrl: credentials.baseUrl,
              apiKey: credentials.apiKey,
              inviteCode: inviteCode,
            ));
      await _finishLocalChange(joining: inviteCode != null);
      return true;
    });
  }

  /// Retries a step that talks to the platform server up to 3 times total,
  /// with a short pause between attempts - just enough to ride out an
  /// occasional slow/dropped connection without surfacing a failure that
  /// would otherwise force the caller all the way back to a fresh
  /// (re-authenticated) attempt for what was really a transient blip.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    const maxAttempts = 3;
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } catch (_) {
        if (attempt >= maxAttempts) rethrow;
        if (retryDelay > Duration.zero) await Future<void>.delayed(retryDelay);
      }
    }
  }

  Future<void> _finishLocalChange({required bool joining}) =>
      db.transaction(() async {
        await db.customStatement(
          "DELETE FROM local_safety_state WHERE id='shop_change'",
        );
        await db.resetForFreshStart();
        await (db.update(
          db.deviceMeta,
        )..where((t) => t.id.equals('device'))).write(
          const DeviceMetaCompanion(
            lastPushedLocalRev: Value(0),
            lastPulledChangeId: Value(0),
          ),
        );
        if (joining) await sync.prepareJoinedShop();
        await onShopChanged?.call(joining);
      });

  Future<bool> resolveChange(
    ActionApproval approval,
    PaystackCredentials credentials,
  ) async {
    await security.consume(approval, 'Resolve shop change');
    return sync.exclusive(() async {
      final journal = await db
          .customSelect(
            "SELECT value FROM local_safety_state WHERE id='shop_change'",
          )
          .getSingleOrNull();
      if (journal == null) return false;
      final details = jsonDecode(journal.data['value'] as String) as Map;
      final source = details['sourceShop'];
      final status = await gateway.getClientStatus(
        baseUrl: credentials.baseUrl,
        apiKey: credentials.apiKey,
      );
      if (status.shopId <= 0) {
        throw StateError('The server did not return the current shop.');
      }
      if (source == status.shopId) {
        await db.customStatement(
          "DELETE FROM local_safety_state WHERE id='shop_change'",
        );
        return false;
      }
      await _finishLocalChange(joining: details['joining'] == true);
      return true;
    });
  }

  Future<Map<String, int>?> restore(
    ActionApproval approval,
    ShopArchive archive,
    SaveRecovery saveRecovery,
  ) async {
    await security.consume(approval, 'Import shop data');
    return sync.exclusive(() async {
      if (await sync.hasPendingShopChange) {
        throw StateError('Resolve the interrupted shop change first.');
      }
      await archive.validate();
      if (!await saveRecovery(await ShopArchive.capture(db))) return null;
      return archive.mergeInto(db);
    });
  }
}
