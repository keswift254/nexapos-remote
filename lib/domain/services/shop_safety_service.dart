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

final shopSafetyProvider = Provider<ShopSafetyService>(
  (ref) => ShopSafetyService(
    ref.watch(appDatabaseProvider),
    ref.watch(syncServiceProvider),
    ref.watch(sensitiveActionProvider),
    ref.watch(platformOnboardingGatewayProvider),
  ),
);

typedef SaveRecovery = Future<bool> Function(ShopArchive archive);

class ShopSafetyService {
  final AppDatabase db;
  final SyncService sync;
  final SensitiveActionService security;
  final PlatformOnboardingGateway gateway;
  ShopSafetyService(this.db, this.sync, this.security, this.gateway);

  Future<bool> changeShop({
    required ActionApproval approval,
    required PaystackCredentials credentials,
    required SaveRecovery saveRecovery,
    String? inviteCode,
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
        final archive = await ShopArchive.capture(db);
        await archive.validate();
        if (!await saveRecovery(archive)) {
          await db.customStatement(
            "DELETE FROM local_safety_state WHERE id='shop_change'",
          );
          return false;
        }
      } catch (_) {
        await db.customStatement(
          "DELETE FROM local_safety_state WHERE id='shop_change'",
        );
        rethrow;
      }
      if (inviteCode == null) {
        await gateway.leaveShop(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
        );
      } else {
        await gateway.joinShop(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
          inviteCode: inviteCode,
        );
      }
      await _finishLocalChange(joining: inviteCode != null);
      return true;
    });
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
