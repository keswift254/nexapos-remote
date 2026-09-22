import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider, Ref;

import '../../core/providers.dart';
import '../../core/result.dart';
import '../../data/payments/platform_http_client.dart'
    show PaystackException, PaystackOfflineException, nexaposPlatformBaseUrl;
import '../../data/payments/platform_onboarding_gateway.dart';
import '../entities/paystack_credentials.dart';
import 'auth_service.dart';
import 'license_service.dart';
import 'paystack_credentials_service.dart';
import 'sync_service.dart';

final deviceReconnectServiceProvider = Provider<DeviceReconnectService>(
  DeviceReconnectService.new,
);

/// Takes a device the shop already knows straight back into that shop, with
/// no invite code.
///
/// A device that lost its local sign-in (cleared browser data, a reinstall
/// that kept the device record, ...) still holds the private registration key
/// it was created with, and the platform's registration_lookup already
/// recognises it ("This device was already registered as ... for ..."). The
/// same key entitles it to recover its own registration, which keeps its place
/// in the shop it had joined - so making the person hunt down a fresh invite
/// code for a shop they are already in was pure friction.
///
/// Only for a device that had JOINED a shop. A shop's own founding device
/// (its owner) is unlocked by its license key, not by this.
class DeviceReconnectService {
  final Ref _ref;

  DeviceReconnectService(this._ref);

  /// Ok(true): reconnected and this device has no shop data yet, so the shop's
  /// data must be downloaded before it can be used. Ok(false): reconnected and
  /// the data it already holds is kept. Failure carries a message for the
  /// person to read.
  Future<Result<bool>> reconnect({required String deviceLabel}) {
    return _ref.read(syncServiceProvider).exclusive<Result<bool>>(() async {
      final label = deviceLabel.trim();
      if (label.isEmpty) return const Result.failure('Enter a label for this device.');
      if (await _ref.read(licenseServiceProvider).membershipBlocked) {
        return const Result.failure(
          'Shop access ended. Contact support to recover the retained local records.',
        );
      }

      final onboarding = _ref.read(platformOnboardingGatewayProvider);
      final meta = _ref.read(syncMetadataProvider);
      final credentialsService = _ref.read(paystackCredentialsServiceProvider);
      try {
        final registration = await onboarding.registerDevice(
          baseUrl: nexaposPlatformBaseUrl,
          deviceId: await meta.deviceId(),
          deviceLabel: label,
          registrationSecret: await meta.registrationSecret(),
        );
        // Recovering the registration replaced the platform's copy of this
        // device's access key, so the new one must be kept whatever happens next.
        await credentialsService.save(
          PaystackCredentials(
            baseUrl: nexaposPlatformBaseUrl,
            apiKey: registration.apiKey,
            currency: 'KES',
            defaultEmail: '',
          ),
        );

        final status = await onboarding.getClientStatus(
          baseUrl: nexaposPlatformBaseUrl,
          apiKey: registration.apiKey,
        );
        if (status.status == 'disabled') {
          return const Result.failure(
            'This device was disabled by the shop and cannot reconnect. '
            'Ask the shop owner, or join again with a new invite code.',
          );
        }
        if (status.isOwner || status.shopId <= 0) {
          return const Result.failure(
            'This device is the owner of its own shop, so it is unlocked with its '
            'license key rather than by reconnecting. Go back and enter the license key.',
          );
        }

        await _ref.read(licenseServiceProvider).confirmJoinedMembership();
        await credentialsService.saveDeviceLabel(label);

        // Data this device still holds is kept and simply catches up. With none
        // (a fresh browser, say) the shop's data is downloaded first.
        if (await _ref.read(authServiceProvider).hasAnyUsers()) {
          return const Result.ok(false);
        }
        await _ref.read(syncServiceProvider).prepareJoinedShop();
        return const Result.ok(true);
      } on PaystackOfflineException catch (e) {
        return Result.failure(
          e.timedOut
              ? 'The server is slow to answer right now. Please try again in a moment.'
              : 'Could not reach the server. Check your internet connection and try again.',
        );
      } on PaystackException catch (e) {
        return Result.failure(e.message);
      } on StateError catch (e) {
        return Result.failure(e.message);
      }
    });
  }
}
