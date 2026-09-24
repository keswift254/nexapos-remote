import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../core/secure_storage_provider.dart';
import '../../core/result.dart';
import '../../data/licensing/license_gateway.dart';
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../data/payments/platform_http_client.dart';
import 'paystack_credentials_service.dart';
import 'session_service.dart';
import 'sync_service.dart';

part 'license_service.g.dart';

const _tokenKey = 'nexapos.license.activationToken';
const _validUntilKey = 'nexapos.license.validUntil';
const _lastSeenKey = 'nexapos.license.lastSeenAt';
const _membershipKey = 'nexapos.license.shopMembership';
// Small grace for legitimate clock jitter (NTP corrections, DST edge
// cases) - real rollback attempts to dodge a days/weeks-long expiry
// window are far larger than this, so it doesn't meaningfully widen
// the loophole while avoiding false positives on ordinary clock nudges.
const _clockRollbackTolerance = Duration(minutes: 10);

/// Whether a cached, still-valid activation exists on this device - the
/// single source of truth app.dart's redirect guard checks, mirroring
/// how hasAnyUsersProvider backs the setup-wizard gate: a plain
/// autodispose FutureProvider re-read fresh on every redirect call
/// rather than cached reactive state, so there's no restore-timing race
/// to get wrong on cold start. Delegates to LicenseService so the same
/// "is the cached license still within its valid_until window" check
/// backs both this and the periodic offline re-check in
/// LicenseService.backgroundVerify.
@riverpod
Future<bool> hasCachedLicense(Ref ref) {
  return ref.watch(licenseServiceProvider).hasAppAccess();
}

/// Purely a ping for _RouterRefreshNotifier to listen to - the int
/// itself carries no meaning beyond "something changed, re-run
/// redirect", which then re-reads hasCachedLicenseProvider fresh. Same
/// two-provider split sessionProvider/hasAnyUsersProvider use together
/// for the setup/login gate.
@Riverpod(keepAlive: true)
class LicenseChangeSignal extends _$LicenseChangeSignal {
  @override
  int build() => 0;

  void bump() => state++;
}

@Riverpod(keepAlive: true)
LicenseGateway licenseGateway(Ref ref) => LicenseGateway();

@Riverpod(keepAlive: true)
LicenseService licenseService(Ref ref) {
  return LicenseService(ref);
}

enum LicenseState {
  /// Licensed and within its validity window (or it never expires).
  active,
  /// The validity window has ended.
  expired,
  /// The vendor ended it before its time (a refund, a dispute).
  revoked,
  /// No license of its own: joined a shop owned by another device, whose
  /// access is kept alive by re-confirming the membership online.
  joined,
  notActivated,
}

/// What the Settings > License screen shows. Read-only: building one never
/// changes what the device has stored (clearing an ended license, and the
/// lock back to the activation screen that follows, stay [backgroundVerify]'s job).
class LicenseStatus {
  const LicenseStatus({
    required this.state,
    this.validUntil,
    this.joinedVerifiedAt,
    this.checkedWithServer = false,
  });

  final LicenseState state;

  /// End of the license window. Null while [state] is [LicenseState.active]
  /// means it never expires.
  final DateTime? validUntil;

  /// Joined devices only: when this device last confirmed its membership.
  final DateTime? joinedVerifiedAt;

  /// True when the license server answered just now; false when this is only
  /// what the device has saved (offline, or the server did not answer).
  final bool checkedWithServer;
}

/// How long a joined device may go without confirming its membership online
/// before it locks - the same 24 hours [LicenseService.hasAppAccess] enforces.
const joinedMembershipGrace = Duration(hours: 24);

/// Online-activate-once, offline-run-forever: [activate] is the only
/// call that must succeed while online; after that the cached token
/// (plus an optional cached valid_until) alone gates the app, and
/// [backgroundVerify] just silently re-checks whenever internet happens
/// to be available. See nexapos-license-server memory doc for the full
/// design rationale.
class LicenseService {
  final Ref _ref;

  LicenseService(this._ref);

  Future<Map<String, dynamic>?> _membership() async {
    final raw = await _ref
        .read(secureStorageProvider)
        .read(key: _membershipKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {'blocked': true};
    }
  }

  Future<bool> get membershipBlocked async =>
      (await _membership())?['blocked'] == true;

  /// True for a device that got into its current shop by joining it (an
  /// invite code, or DeviceReconnectService's no-code reconnect - see
  /// confirmJoinedMembership), as opposed to the device that founded the
  /// shop by activating a license key. Purely local, no network call - lets
  /// a screen tell the two apart (e.g. "Leave this shop") without first
  /// asking the server who owns what.
  Future<bool> get isJoinedMember async => await _membership() != null;

  Future<bool> hasAppAccess() async {
    final membership = await _membership();
    if (membership?['blocked'] == true) return false;
    if (await hasValidCachedLicense()) return true;
    if (membership == null) return false;
    final verified = DateTime.tryParse(
      membership['verifiedAt'] as String? ?? '',
    );
    if (verified == null) return false;
    final now = _ref.read(clockProvider).now();
    if (now.isBefore(verified.subtract(_clockRollbackTolerance)) ||
        now.difference(verified) >= joinedMembershipGrace) {
      return false;
    }
    return membership['deviceId'] ==
        await _ref.read(syncMetadataProvider).deviceId();
  }

  /// Called only after a successful invite redemption, never registration alone.
  Future<void> confirmJoinedMembership() async {
    if (await membershipBlocked) {
      throw StateError('Shop access was removed. Contact support.');
    }
    final credentials = await _ref
        .read(paystackCredentialsServiceProvider)
        .load();
    final status = await _ref
        .read(platformOnboardingGatewayProvider)
        .getClientStatus(
          baseUrl: credentials.baseUrl,
          apiKey: credentials.apiKey,
        );
    if (status.isOwner || status.shopId <= 0 || status.status == 'disabled') {
      throw StateError('An active invitation to an existing shop is required.');
    }
    await _writeMembership(status.shopId);
  }

  Future<void> _writeMembership(int shopId) async {
    await _ref
        .read(secureStorageProvider)
        .write(
          key: _membershipKey,
          value: jsonEncode({
            'shopId': shopId,
            'deviceId': await _ref.read(syncMetadataProvider).deviceId(),
            'verifiedAt': _ref
                .read(clockProvider)
                .now()
                .toUtc()
                .toIso8601String(),
            'blocked': false,
          }),
        );
    _notifyAccessChanged();
  }

  Future<void> clearJoinedMembership() async {
    await _ref.read(secureStorageProvider).delete(key: _membershipKey);
    _notifyAccessChanged();
  }

  void _notifyAccessChanged() {
    _ref.invalidate(hasCachedLicenseProvider);
    _ref.read(licenseChangeSignalProvider.notifier).bump();
  }

  /// A confirmed revocation (the shop owner used Connected Devices, this
  /// device switched shops, or the server otherwise genuinely ended its
  /// membership - never just a network hiccup, see verifyJoinedMembership's
  /// PaystackOfflineException branch, which calls _notifyAccessChanged
  /// instead of this) wipes this device back to a fresh-install state:
  /// every business table, the platform registration, and the
  /// membership record itself. That's a deliberate change from the
  /// previous "mark blocked, keep the data, tell them to contact
  /// support" design - a device that's been cut off from a shop has no
  /// legitimate further use for that shop's data, and the whole point
  /// of "Connected Devices" revoke is that the device is gone for good,
  /// not parked in a locked half-state. Fully deleting the membership
  /// key (not just flagging it) also means a device that separately
  /// holds its own genuinely-activated license - a real, independent
  /// grant of access, not the joined-shop membership being revoked
  /// here - still works normally afterward via hasValidCachedLicense,
  /// exactly as clearJoinedMembership already preserves for a voluntary
  /// leave; only the joined-shop membership and its data are cleared.
  Future<void> _blockMembership(Map<String, dynamic> membership) async {
    await _ref.read(appDatabaseProvider).resetForFreshStart();
    await _ref.read(paystackCredentialsServiceProvider).clearRegistration();
    await _ref.read(secureStorageProvider).delete(key: _membershipKey);
    await _ref.read(sessionProvider.notifier).logout();
    _notifyAccessChanged();
  }

  Future<void> verifyJoinedMembership() =>
      _ref.read(syncServiceProvider).exclusive(() async {
        if (await _ref.read(syncServiceProvider).hasPendingShopChange) return;
        final membership = await _membership();
        if (membership == null || membership['blocked'] == true) return;
        final credentials = await _ref
            .read(paystackCredentialsServiceProvider)
            .load();
        if (!credentials.isConfigured) {
          await _blockMembership(membership);
          return;
        }
        try {
          final status = await _ref
              .read(platformOnboardingGatewayProvider)
              .getClientStatus(
                baseUrl: credentials.baseUrl,
                apiKey: credentials.apiKey,
              );
          if (status.isOwner ||
              status.shopId != membership['shopId'] ||
              status.status == 'disabled') {
            await _blockMembership(membership);
          } else {
            await _writeMembership(status.shopId);
          }
        } on PaystackOfflineException {
          _notifyAccessChanged();
        } on PaystackException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 403) {
            await _blockMembership(membership);
          } else {
            _notifyAccessChanged();
          }
        }
      });

  Future<void> _resetQueue = Future.value();

  Future<void> _applyAuthenticatorReset(int generation) {
    final operation = _resetQueue.then((_) async {
      if (generation <= 0) return;
      final storage = _ref.read(secureStorageProvider);
      const marker = 'nexapos.authenticator.resetGeneration';
      final previous = int.tryParse(await storage.read(key: marker) ?? '') ?? 0;
      if (generation <= previous) return;
      for (final key in (await storage.readAll()).keys) {
        if (key.startsWith('nexapos.security.')) await storage.delete(key: key);
      }
      await storage.write(key: marker, value: '$generation');
    });
    _resetQueue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> checkAuthenticatorReset() async {
    final token = await _ref.read(secureStorageProvider).read(key: _tokenKey);
    if (token == null) throw StateError('Activate this device first.');
    final result = await _ref
        .read(licenseGatewayProvider)
        .verify(baseUrl: licenseServerBaseUrl, activationToken: token);
    if (!result.valid) throw StateError('Renew the device license first.');
    await _applyAuthenticatorReset(result.authenticatorGeneration);
  }

  Future<void> authorizeSupport(String password) async {
    final token = await _ref.read(secureStorageProvider).read(key: _tokenKey);
    if (token == null) throw StateError('Activate this device first.');
    await _ref
        .read(licenseGatewayProvider)
        .redeemSupport(
          baseUrl: licenseServerBaseUrl,
          activationToken: token,
          deviceId: await _ref.read(syncMetadataProvider).deviceId(),
          password: password.trim(),
        );
  }

  Future<Result<void>> activate(String code) async {
    if (await membershipBlocked) {
      return const Result.failure(
        'This device was removed from its shop. Local records are retained. Contact support to recover them before setting up a new shop.',
      );
    }
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      return const Result.failure('Enter your license key.');
    }

    final deviceId = await _ref.read(syncMetadataProvider).deviceId();
    try {
      final result = await _ref
          .read(licenseGatewayProvider)
          .activate(
            baseUrl: licenseServerBaseUrl,
            code: trimmedCode,
            deviceId: deviceId,
          );
      final storage = _ref.read(secureStorageProvider);
      await storage.write(key: _tokenKey, value: result.token);
      await _writeValidUntil(storage, result.validUntil);
      _ref.invalidate(hasCachedLicenseProvider);
      _ref.read(licenseChangeSignalProvider.notifier).bump();
      return const Result.ok(null);
    } on LicenseOfflineException {
      return const Result.failure(
        'Could not reach the license server. Check your internet connection and try again.',
      );
    } on LicenseException catch (e) {
      return Result.failure(e.message);
    }
  }

  /// The offline-enforceable half of "is this device still licensed" -
  /// a cached token with no valid_until (or one still in the future)
  /// counts as licensed with zero network access required. This is what
  /// makes a license-duration expiry actually deactivate the app on
  /// schedule even if it never reaches the server again after
  /// activation - not just something verify() happens to reject next
  /// time it's reachable.
  Future<bool> hasValidCachedLicense() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return false;
    return !await _isExpired(storage);
  }

  /// The license state for the Settings > License screen. With [askServer]
  /// it first asks the license server (so a revoke or an extension made by
  /// the vendor shows up immediately, not on the next 15-second cycle) and
  /// falls back to what this device has saved when the server cannot be
  /// reached - the offline answer is the same one the app itself enforces.
  /// The server does not say WHY a license is invalid, but it does return
  /// the license's end date: an end date already past means it ran out, any
  /// other invalid answer means it was revoked.
  Future<LicenseStatus> currentStatus({bool askServer = true}) async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      final membership = await _membership();
      if (membership == null) {
        return const LicenseStatus(state: LicenseState.notActivated);
      }
      if (membership['blocked'] == true) {
        return const LicenseStatus(state: LicenseState.revoked);
      }
      return LicenseStatus(
        state: LicenseState.joined,
        joinedVerifiedAt: DateTime.tryParse(
          membership['verifiedAt'] as String? ?? '',
        ),
      );
    }

    final expiredLocally = await _isExpired(storage);
    final savedRaw = await storage.read(key: _validUntilKey);
    final savedValidUntil = savedRaw == null || savedRaw.isEmpty
        ? null
        : DateTime.tryParse(savedRaw);

    if (askServer) {
      try {
        final result = await _ref
            .read(licenseGatewayProvider)
            .verify(baseUrl: licenseServerBaseUrl, activationToken: token);
        final now = _ref.read(clockProvider).now();
        if (!result.valid) {
          final ranOut =
              result.validUntil != null && !result.validUntil!.isAfter(now);
          return LicenseStatus(
            state: ranOut ? LicenseState.expired : LicenseState.revoked,
            validUntil: result.validUntil ?? savedValidUntil,
            checkedWithServer: true,
          );
        }
        return LicenseStatus(
          state: expiredLocally ? LicenseState.expired : LicenseState.active,
          validUntil: result.validUntil,
          checkedWithServer: true,
        );
      } on LicenseOfflineException {
        // Fall through to what is saved on this device.
      } on LicenseException {
        // Same: a server hiccup must not make a good license look bad.
      }
    }

    return LicenseStatus(
      state: expiredLocally ? LicenseState.expired : LicenseState.active,
      validUntil: savedValidUntil,
    );
  }

  /// Called from app.dart's existing periodic sync timer - never called
  /// from a blocking UI path (checkout must never wait on this).
  /// Checks the offline-enforceable expiry FIRST, regardless of
  /// connectivity, so a license-duration expiry is caught within one
  /// timer cycle even with zero internet access, not just incidentally
  /// whenever the next navigation happens to re-run the redirect guard.
  /// Beyond that, any failure to reach the server is deliberately
  /// swallowed and leaves the cached activation alone; only an explicit
  /// {valid:false} from a server that WAS reached (revoked, or the
  /// server's own valid_until check agrees it's expired) clears the
  /// cached token and locks the app back to the activation screen.
  Future<void> backgroundVerify() async {
    await verifyJoinedMembership();
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return;

    if (await _isExpired(storage)) {
      await _clearLicense(storage);
      return;
    }

    try {
      final result = await _ref
          .read(licenseGatewayProvider)
          .verify(baseUrl: licenseServerBaseUrl, activationToken: token);
      if (!result.valid) {
        await _clearLicense(storage);
        return;
      }
      // Keeps the locally-cached deadline in sync with the server's -
      // covers a vendor-side revoke/extend that changed valid_until
      // without this device needing to reactivate.
      await _writeValidUntil(storage, result.validUntil);
      await _applyAuthenticatorReset(result.authenticatorGeneration);
    } on LicenseOfflineException {
      // No internet right now - stay licensed, try again next cycle.
    } on LicenseException {
      // Transient server-side error - stay licensed, try again next cycle.
    }
  }

  Future<bool> _isExpired(FlutterSecureStorage storage) async {
    final now = _ref.read(clockProvider).now();
    // Always tracked, regardless of whether a valid_until is even set,
    // so the protection already has a baseline the moment a
    // subscription-style license shows up later via re-activation.
    final rolledBack = await _trackClockAndDetectRollback(storage, now);

    final raw = await storage.read(key: _validUntilKey);
    if (raw == null || raw.isEmpty) {
      return false; // never expires - nothing to dodge, rollback is moot
    }
    final validUntil = DateTime.tryParse(raw);
    if (validUntil == null) return false;

    // A rolled-back clock can't be trusted to say "not expired yet" -
    // this is the actual defense: without it, winding the system clock
    // back to before valid_until would make an offline check pass again.
    if (rolledBack) return true;
    return !validUntil.isAfter(now);
  }

  /// Maintains a monotonic watermark (secure storage key
  /// nexapos.license.lastSeenAt) of the latest time this device has
  /// ever legitimately observed - never moves backward, persists across
  /// activate()/_clearLicense (it's a device-level fact, not tied to
  /// any one license's lifecycle, otherwise a rollback-then-reactivate
  /// cycle would just reset it and defeat the whole point). Returns
  /// whether `now` is suspiciously earlier than that watermark, beyond
  /// [_clockRollbackTolerance].
  Future<bool> _trackClockAndDetectRollback(
    FlutterSecureStorage storage,
    DateTime now,
  ) async {
    final lastSeenRaw = await storage.read(key: _lastSeenKey);
    final lastSeen = lastSeenRaw != null && lastSeenRaw.isNotEmpty
        ? DateTime.tryParse(lastSeenRaw)
        : null;
    final rolledBack =
        lastSeen != null && lastSeen.difference(now) > _clockRollbackTolerance;
    if (lastSeen == null || now.isAfter(lastSeen)) {
      await storage.write(key: _lastSeenKey, value: now.toIso8601String());
    }
    return rolledBack;
  }

  Future<void> _writeValidUntil(
    FlutterSecureStorage storage,
    DateTime? validUntil,
  ) async {
    if (validUntil == null) {
      await storage.delete(key: _validUntilKey);
    } else {
      await storage.write(
        key: _validUntilKey,
        value: validUntil.toIso8601String(),
      );
    }
  }

  /// Deliberately does NOT delete _lastSeenKey - see
  /// _trackClockAndDetectRollback's doc for why that watermark must
  /// outlive any single license.
  Future<void> _clearLicense(FlutterSecureStorage storage) async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _validUntilKey);
    _ref.invalidate(hasCachedLicenseProvider);
    _ref.read(licenseChangeSignalProvider.notifier).bump();
  }
}
