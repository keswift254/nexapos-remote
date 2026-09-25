import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/secure_storage_provider.dart';
import '../../data/licensing/license_gateway.dart';
import 'license_service.dart';

const _pendingKey = 'nexapos.purchase.pending';
const _emailKey = 'nexapos.purchase.email';
const _offlineMessage =
    'Could not reach the server. Check your internet connection and try again.';

/// A payment that was started and not yet settled either way is remembered this
/// long, so closing the app (or the phone dying) between paying and getting the
/// license does not lose it. After that the app forgets it; the server still
/// has the record if someone needs to be helped.
const pendingPurchaseLifetime = Duration(hours: 24);

/// A purchase the customer has begun. Kept on the device (not just in memory)
/// because the payment happens on another page and may outlive the app.
class PendingPurchase {
  const PendingPurchase({
    required this.reference,
    required this.planId,
    required this.planLabel,
    required this.amountKes,
    required this.paymentUrl,
    required this.startedAt,
  });

  final String reference;
  final String planId;
  final String planLabel;
  final int amountKes;

  /// Where the customer pays; kept so "open the payment page again" still works
  /// after the app was closed.
  final String paymentUrl;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
    'reference': reference,
    'planId': planId,
    'planLabel': planLabel,
    'amountKes': amountKes,
    'paymentUrl': paymentUrl,
    'startedAt': startedAt.toUtc().toIso8601String(),
  };

  static PendingPurchase? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final reference = decoded['reference'];
    final planId = decoded['planId'];
    final label = decoded['planLabel'];
    final amount = decoded['amountKes'];
    final url = decoded['paymentUrl'];
    final startedAt = DateTime.tryParse(decoded['startedAt'] as String? ?? '');
    if (reference is! String ||
        reference.isEmpty ||
        planId is! String ||
        label is! String ||
        amount is! num ||
        url is! String ||
        startedAt == null) {
      return null;
    }
    return PendingPurchase(
      reference: reference,
      planId: planId,
      planLabel: label,
      amountKes: amount.toInt(),
      paymentUrl: url,
      startedAt: startedAt,
    );
  }
}

enum PurchaseCheckKind {
  /// Nothing is in progress.
  none,

  /// Not paid yet (or Paystack has not confirmed it yet): keep waiting.
  pending,

  /// The server could not be reached; the payment itself is not in doubt.
  offline,

  /// Paid, the license was issued and this device is now activated.
  activated,

  /// The payment did not go through. Final: start again.
  failed,

  /// Something went wrong AFTER a payment (e.g. activating): the payment is
  /// kept and this is tried again.
  problem,
}

class PurchaseCheck {
  const PurchaseCheck(this.kind, [this.message]);

  final PurchaseCheckKind kind;
  final String? message;
}

/// How a step of restoring a license went, in words fit to show. Restoring never
/// throws at the screen: every way it can go wrong is a message.
class RestoreOutcome {
  const RestoreOutcome.ok([this.message]) : ok = true;
  const RestoreOutcome.failed(String this.message) : ok = false;

  final bool ok;
  final String? message;
}

/// Opens a web address in the person's browser. Injectable so screens can be
/// tested without one.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Buying a license from the activation screen: choose a plan, pay on
/// Paystack's page, and the device is activated by itself when the payment is
/// confirmed. Everything that matters (price, length, whether the payment
/// really happened, the license itself) is decided by the license server - see
/// its Purchases service. This just carries the customer through it.
class LicensePurchaseService {
  LicensePurchaseService(
    this._ref, {
    this.identityTimeout = const Duration(seconds: 15),
    this.storageTimeout = const Duration(seconds: 8),
  });

  final Ref _ref;

  /// How long to wait for this device to say who it is, and for its storage to
  /// answer, before giving up with a message instead of waiting for ever. (A
  /// browser's storage or database can stall - a private window, a tab that was
  /// left open across an update - and a payment screen that spins without end,
  /// with no words, is the worst way to find out.)
  final Duration identityTimeout;
  final Duration storageTimeout;

  /// This device's id, or a [LicenseException] that says what to do - never a hang
  /// and never a raw error.
  Future<String> _deviceId() async {
    try {
      return await _ref
          .read(syncMetadataProvider)
          .deviceId()
          .timeout(identityTimeout);
    } on TimeoutException {
      throw const LicenseException(
        'This device did not answer in time. Close NexaPOS (or reload the page) and '
        'open it again, then try again.',
      );
    } catch (error) {
      throw LicenseException(
        'This device could not be identified (${_short(error)}). Close NexaPOS '
        '(or reload the page), open it again, and try again.',
      );
    }
  }

  static String _short(Object error) {
    final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 120 ? text : '${text.substring(0, 117)}...';
  }

  /// Writes to storage, but never lets a stalled or failing write get in the way
  /// of what the person is doing: remembering a payment across a restart is a
  /// courtesy, paying is the point.
  Future<void> _remember(String key, String value) async {
    try {
      await _ref
          .read(secureStorageProvider)
          .write(key: key, value: value)
          .timeout(storageTimeout);
    } catch (_) {}
  }

  Future<PlanCatalog> loadPlans() => _ref
      .read(licenseGatewayProvider)
      .fetchPlans(baseUrl: licenseServerBaseUrl);

  /// The email last paid with, to save typing it again.
  Future<String?> lastEmail() async {
    try {
      return await _ref
          .read(secureStorageProvider)
          .read(key: _emailKey)
          .timeout(storageTimeout);
    } catch (_) {
      return null; // a convenience, not worth a message
    }
  }

  Future<PendingPurchase?> pending() async {
    final storage = _ref.read(secureStorageProvider);
    final String? raw;
    try {
      raw = await storage.read(key: _pendingKey).timeout(storageTimeout);
    } catch (_) {
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    PendingPurchase? purchase;
    try {
      purchase = PendingPurchase.fromJson(jsonDecode(raw));
    } catch (_) {}
    if (purchase == null ||
        DateTime.now().toUtc().difference(purchase.startedAt) >
            pendingPurchaseLifetime) {
      await storage.delete(key: _pendingKey);
      return null;
    }
    return purchase;
  }

  /// Asks the server for a checkout page and remembers the purchase. Throws
  /// [LicenseException] (the server's own words, fit to show) or
  /// [LicenseOfflineException].
  Future<PendingPurchase> start(PurchasePlan plan, String email) async {
    final deviceId = await _deviceId();
    final checkout = await _ref
        .read(licenseGatewayProvider)
        .startCheckout(
          baseUrl: licenseServerBaseUrl,
          deviceId: deviceId,
          planId: plan.id,
          email: email.trim(),
        );
    final purchase = PendingPurchase(
      reference: checkout.reference,
      planId: plan.id,
      planLabel: plan.label,
      amountKes: plan.amountKes,
      paymentUrl: checkout.paymentUrl.toString(),
      startedAt: DateTime.now().toUtc(),
    );
    await _remember(_pendingKey, jsonEncode(purchase.toJson()));
    await _remember(_emailKey, email.trim());
    return purchase;
  }

  Future<bool> openPaymentPage(PendingPurchase purchase) async {
    try {
      return await _ref.read(urlOpenerProvider)(Uri.parse(purchase.paymentUrl));
    } catch (_) {
      return false;
    }
  }

  /// One look at how the payment is doing. When it has been paid this also
  /// activates the device with the license the server issued, so a caller only
  /// has to react to [PurchaseCheckKind.activated].
  Future<PurchaseCheck> check() async {
    final purchase = await pending();
    if (purchase == null) return const PurchaseCheck(PurchaseCheckKind.none);

    final PurchaseStatus status;
    try {
      final deviceId = await _deviceId();
      status = await _ref
          .read(licenseGatewayProvider)
          .checkoutStatus(
            baseUrl: licenseServerBaseUrl,
            reference: purchase.reference,
            deviceId: deviceId,
          );
    } on LicenseOfflineException {
      return const PurchaseCheck(
        PurchaseCheckKind.offline,
        'Could not reach the server. Your payment is safe - it will be '
        'checked again as soon as you are online.',
      );
    } on LicenseException catch (e) {
      if (e.message.contains('Unknown payment')) {
        await cancel();
        return const PurchaseCheck(
          PurchaseCheckKind.failed,
          'This payment could not be found. If you paid, contact NexaPOS '
          'with your receipt.',
        );
      }
      return PurchaseCheck(PurchaseCheckKind.problem, e.message);
    } catch (error) {
      // Anything unexpected: the payment is safe on the server - say so and keep
      // trying, instead of a waiting box that never says anything.
      return PurchaseCheck(
        PurchaseCheckKind.problem,
        'Could not check the payment just now (${_short(error)}). Your payment '
        'is safe - trying again.',
      );
    }

    switch (status.state) {
      case PurchaseState.pending:
        return const PurchaseCheck(PurchaseCheckKind.pending);
      case PurchaseState.failed:
        await cancel();
        return PurchaseCheck(
          PurchaseCheckKind.failed,
          status.message ?? 'The payment did not go through.',
        );
      case PurchaseState.issued:
        final activated = await _ref
            .read(licenseServiceProvider)
            .activate(status.code!);
        return await activated.when(
          ok: (_) async {
            await cancel();
            return const PurchaseCheck(PurchaseCheckKind.activated);
          },
          // Paid for and issued, but this device could not take it yet (no
          // internet at that instant, say): keep the purchase, try again.
          failure: (message) async =>
              PurchaseCheck(PurchaseCheckKind.problem, message),
        );
    }
  }

  /// Restoring a license after a reinstall or a new phone. The license is bound
  /// to the device it was first used on, and a fresh install is a new device, so
  /// the customer proves they own the email they paid with: the server emails a
  /// code to it, and entering the code moves the license to this device.
  ///
  /// Step 1. The reply is deliberately the same whether or not that email ever
  /// bought anything.
  Future<RestoreOutcome> requestRestoreCode(String email) async {
    final trimmed = email.trim();
    try {
      final deviceId = await _deviceId();
      final message = await _ref
          .read(licenseGatewayProvider)
          .restoreStart(
            baseUrl: licenseServerBaseUrl,
            deviceId: deviceId,
            email: trimmed,
          );
      await _remember(_emailKey, trimmed);
      return RestoreOutcome.ok(message.isEmpty ? null : message);
    } on LicenseOfflineException {
      return const RestoreOutcome.failed(_offlineMessage);
    } on LicenseException catch (e) {
      return RestoreOutcome.failed(e.message);
    }
  }

  /// Step 2. When the code is right the license arrives on this device and is
  /// activated here, so a caller only has to react to [RestoreOutcome.ok].
  Future<RestoreOutcome> restore(String email, String code) async {
    final String license;
    try {
      final deviceId = await _deviceId();
      license = await _ref
          .read(licenseGatewayProvider)
          .restoreConfirm(
            baseUrl: licenseServerBaseUrl,
            deviceId: deviceId,
            email: email.trim(),
            code: code.trim(),
          );
    } on LicenseOfflineException {
      return const RestoreOutcome.failed(_offlineMessage);
    } on LicenseException catch (e) {
      return RestoreOutcome.failed(e.message);
    }
    final activated = await _ref.read(licenseServiceProvider).activate(license);
    return activated.when(
      ok: (_) => const RestoreOutcome.ok(),
      failure: RestoreOutcome.failed,
    );
  }

  /// Forgets the purchase on this device. Does not undo a payment already made:
  /// the server keeps its record of it.
  Future<void> cancel() =>
      _ref.read(secureStorageProvider).delete(key: _pendingKey);
}

final licensePurchaseServiceProvider = Provider<LicensePurchaseService>(
  (ref) => LicensePurchaseService(ref),
);
