import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../core/secure_storage_provider.dart';
import '../../core/result.dart';
import '../../core/utils/monotonic_clock.dart';
import '../../data/licensing/license_gateway.dart';
import '../../data/payments/platform_onboarding_gateway.dart';
import '../../data/payments/platform_http_client.dart';
import 'license_lease.dart';
import 'paystack_credentials_service.dart';
import 'session_service.dart';
import 'sync_service.dart';

export 'license_lease.dart' show LeaseOffer, LicenseLease;

part 'license_service.g.dart';

const _leaseKey = 'nexapos.license.lease';
const _tokenKey = 'nexapos.license.activationToken';
const _validUntilKey = 'nexapos.license.validUntil';
const _lastSeenKey = 'nexapos.license.lastSeenAt';
const _lastEndKey = 'nexapos.license.lastEnd';
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
    this.sharedRemaining,
    this.sharedNeverExpires = false,
  });

  final LicenseState state;

  /// Joined devices only: time left on the shop's license, as received from
  /// the shop's main device and counted down here. Null until one was received.
  final Duration? sharedRemaining;
  final bool sharedNeverExpires;

  /// End of the license window. Null while [state] is [LicenseState.active]
  /// means it never expires.
  final DateTime? validUntil;

  /// Joined devices only: when this device last confirmed its membership.
  final DateTime? joinedVerifiedAt;

  /// True when the license server answered just now; false when this is only
  /// what the device has saved (offline, or the server did not answer).
  final bool checkedWithServer;
}

enum LicenseEndReason {
  /// The validity window ran out.
  expired,
  /// The vendor ended it before its time.
  revoked,
  /// This device's clock reads earlier than the device has already seen, so
  /// the license end date cannot be trusted (see the clock-rollback guard).
  clockSetBack,
  /// A joined device: the license of the shop it follows ran out.
  shopLicenseExpired,
}

/// Why the license this device used to hold no longer counts - what the
/// activation screen tells the user instead of a bare "Activate NexaPOS".
/// Written the moment [LicenseService.backgroundVerify] locks the app, and
/// removed once a license is activated again.
class LicenseEnd {
  const LicenseEnd({required this.reason, this.validUntil, this.noticedAt});

  final LicenseEndReason reason;

  /// The license's end date, when it had one.
  final DateTime? validUntil;

  /// When this device found out.
  final DateTime? noticedAt;

  Map<String, dynamic> toJson() => {
    'reason': reason.name,
    'validUntil': validUntil?.toUtc().toIso8601String(),
    'noticedAt': noticedAt?.toUtc().toIso8601String(),
  };

  static LicenseEnd? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final reason = LicenseEndReason.values
        .where((r) => r.name == decoded['reason'])
        .firstOrNull;
    if (reason == null) return null;
    return LicenseEnd(
      reason: reason,
      validUntil: DateTime.tryParse(decoded['validUntil'] as String? ?? ''),
      noticedAt: DateTime.tryParse(decoded['noticedAt'] as String? ?? ''),
    );
  }
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

  LicenseService(this._ref)
    : _leaseCountdown = LeaseCountdown(
        _ref.read(clockProvider),
        _ref.read(monotonicClockProvider),
      );

  final LeaseCountdown _leaseCountdown;
  Duration? _lastLeaseWrite;

  /// A received lease replaces the one already held only when it has more
  /// time left by at least this much - shared counts differ by seconds, and
  /// that must not cause a rewrite on every exchange.
  static const _leaseAdoptMargin = Duration(minutes: 1);

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
    // A joined device that has been given the shop's license lives by it: it
    // works, online or not, until that license runs out. It is only a device
    // that never received one (its shop's main device is on an older version,
    // or they have never been in touch) that still has to re-confirm online.
    final lease = await _advanceLease();
    if (lease != null) {
      if (lease.isExpired) return false;
      return membership['deviceId'] ==
          await _ref.read(syncMetadataProvider).deviceId();
    }
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

  /// True for a device that joined a shop and is locked out right now only
  /// because it has not been able to confirm that membership online (more than
  /// [joinedMembershipGrace] ago, or its clock reads earlier than the last
  /// confirmation). Nothing was removed: its data is intact and it reopens by
  /// itself the next time a check gets through, so the activation screen tells
  /// it to get online instead of looking like a fresh install. Deliberately
  /// derived from [hasAppAccess], the very rule that locked it, so this notice
  /// can never disagree with the lock. A confirmed removal is a different
  /// thing (the membership is gone, [membershipBlocked]) and gets no notice.
  Future<bool> joinedShopNeedsInternet() async {
    final membership = await _membership();
    if (membership == null || membership['blocked'] == true) return false;
    // Following the shop's license, the only way to be locked is for that
    // license to have run out - a different message, and no internet needed.
    if (await _readLease() != null) return false;
    return !await hasAppAccess();
  }

  Future<LicenseLease?> _readLease() async {
    final raw = await _ref.read(secureStorageProvider).read(key: _leaseKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LicenseLease.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLease(LicenseLease lease) async {
    _lastLeaseWrite = _ref.read(monotonicClockProvider).elapsed();
    await _ref
        .read(secureStorageProvider)
        .write(key: _leaseKey, value: jsonEncode(lease.toJson()));
  }

  /// The lease this joined device follows, brought up to date with the present
  /// (see [LeaseCountdown] for exactly how time is counted). Saved at most every
  /// few seconds - the count is rebuilt from what is saved, so a crash costs
  /// nothing but the last few seconds' rounding.
  Future<LicenseLease?> _advanceLease() async {
    final saved = await _readLease();
    if (saved == null) return null;
    final advanced = _leaseCountdown.advance(saved);
    final last = _lastLeaseWrite;
    final now = _ref.read(monotonicClockProvider).elapsed();
    if (last == null ||
        now - last >= const Duration(seconds: 5) ||
        (advanced.isExpired && !saved.isExpired)) {
      await _writeLease(advanced);
    }
    return advanced;
  }

  /// The shop's license as this device currently counts it, or null when this
  /// device does not follow one. For the Settings screen.
  Future<LicenseLease?> currentLease() => _advanceLease();

  /// What to hand to another device of the same shop. The shop's main device
  /// (the one holding the license) offers the time its own license has left;
  /// a joined device passes on the lease it follows. Null when there is
  /// nothing worth giving (no license, or an ended one).
  Future<LeaseOffer?> leaseToShare() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      if (await _isExpired(storage)) return null;
      final validUntil = await _savedValidUntil(storage);
      if (validUntil == null) {
        return const LeaseOffer(remaining: Duration.zero, neverExpires: true);
      }
      final left = validUntil.difference(_ref.read(clockProvider).now());
      return left > Duration.zero ? LeaseOffer(remaining: left) : null;
    }
    final lease = await _advanceLease();
    if (lease == null || lease.isExpired) return null;
    return LeaseOffer(
      remaining: lease.remaining,
      neverExpires: lease.neverExpires,
    );
  }

  /// Takes the license time another device of the shop offers. Only a joined
  /// device follows a lease, and one holding a valid license of its own never
  /// does. A lease is only ever replaced by one with MORE time left: a shop's
  /// license can be extended but not shortened, so this both carries a renewal
  /// to every device and wipes out whatever error a device's own counting has
  /// picked up (the shop's main device is the reference). Returns whether the
  /// offer was taken.
  Future<bool> acceptLease(LeaseOffer offer) async {
    final membership = await _membership();
    if (membership == null || membership['blocked'] == true) return false;
    if (await hasValidCachedLicense()) return false;
    final current = await _advanceLease();
    final better = current == null
        ? true
        : current.neverExpires
        ? false
        : offer.neverExpires ||
              offer.remaining > current.remaining + _leaseAdoptMargin;
    if (!better) return false;
    final storage = _ref.read(secureStorageProvider);
    final adopted = LicenseLease(
      remaining: offer.remaining,
      neverExpires: offer.neverExpires,
      accountedAt: _ref.read(clockProvider).now(),
    );
    await _writeLease(adopted);
    // Start counting from this very moment (rather than from the next check),
    // so a date change in the seconds after receiving it is not mistaken for
    // time the app was closed.
    _leaseCountdown
      ..reset()
      ..advance(adopted);
    // A renewal ends the "the shop's license expired" notice.
    await storage.delete(key: _lastEndKey);
    _notifyAccessChanged();
    return true;
  }

  /// Once the shop's license has run out on a device that follows it, say so
  /// once (the notice on the activation screen) and let the app re-check what
  /// this device may open. Runs on the app's regular background check.
  Future<void> _enforceLease() async {
    final lease = await _advanceLease();
    if (lease == null || !lease.isExpired) return;
    final storage = _ref.read(secureStorageProvider);
    final recorded = await storage.read(key: _lastEndKey);
    if (recorded != null && recorded.contains(LicenseEndReason.shopLicenseExpired.name)) {
      return;
    }
    await storage.write(
      key: _lastEndKey,
      value: jsonEncode(
        LicenseEnd(
          reason: LicenseEndReason.shopLicenseExpired,
          noticedAt: _ref.read(clockProvider).now(),
        ).toJson(),
      ),
    );
    _notifyAccessChanged();
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
    // A new join starts from nothing: it may be a different shop from the one
    // whose license a previous membership followed, and access now comes from
    // that shop, so an old "your license ended" notice no longer applies.
    // (Not done in _writeMembership: that also runs on every routine
    // re-confirmation, which must not wipe a notice that is still true.)
    await _dropLease();
    await _ref.read(secureStorageProvider).delete(key: _lastEndKey);
    await _writeMembership(status.shopId);
  }

  Future<void> _dropLease() async {
    _leaseCountdown.reset();
    await _ref.read(secureStorageProvider).delete(key: _leaseKey);
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
    await _dropLease();
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
    await _dropLease();
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
      // Licensed again - the "your license ended" notice no longer applies.
      await storage.delete(key: _lastEndKey);
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
      final lease = await _advanceLease();
      return LicenseStatus(
        state: lease != null && lease.isExpired
            ? LicenseState.expired
            : LicenseState.joined,
        joinedVerifiedAt: DateTime.tryParse(
          membership['verifiedAt'] as String? ?? '',
        ),
        sharedRemaining: lease?.neverExpires == true ? null : lease?.remaining,
        sharedNeverExpires: lease?.neverExpires ?? false,
      );
    }

    final expiredLocally = await _isExpired(storage);
    final savedValidUntil = await _savedValidUntil(storage);

    if (askServer) {
      try {
        final result = await _ref
            .read(licenseGatewayProvider)
            .verify(baseUrl: licenseServerBaseUrl, activationToken: token);
        final now = _ref.read(clockProvider).now();
        if (!result.valid) {
          return LicenseStatus(
            state: _ranOut(result.validUntil, now)
                ? LicenseState.expired
                : LicenseState.revoked,
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
    await _enforceLease();
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return;

    if (await _isExpired(storage)) {
      await _clearLicense(storage, end: await _endFromSavedLicense(storage));
      return;
    }

    try {
      final result = await _ref
          .read(licenseGatewayProvider)
          .verify(baseUrl: licenseServerBaseUrl, activationToken: token);
      if (!result.valid) {
        final now = _ref.read(clockProvider).now();
        final saved = await _savedValidUntil(storage);
        await _clearLicense(
          storage,
          end: LicenseEnd(
            reason: _ranOut(result.validUntil, now)
                ? LicenseEndReason.expired
                : LicenseEndReason.revoked,
            validUntil: result.validUntil ?? saved,
            noticedAt: now,
          ),
        );
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

  /// True when [validUntil] is a real end date that has already passed.
  bool _ranOut(DateTime? validUntil, DateTime now) =>
      validUntil != null && !validUntil.isAfter(now);

  Future<DateTime?> _savedValidUntil(FlutterSecureStorage storage) async {
    final raw = await storage.read(key: _validUntilKey);
    return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  /// Why the license saved on this device counts as ended right now, judged
  /// only from what is saved (no network): an end date that has passed means
  /// it ran out; a locally-expired license whose end date is still ahead can
  /// only be the clock-rollback guard firing.
  Future<LicenseEnd> _endFromSavedLicense(FlutterSecureStorage storage) async {
    final now = _ref.read(clockProvider).now();
    final validUntil = await _savedValidUntil(storage);
    return LicenseEnd(
      reason: _ranOut(validUntil, now)
          ? LicenseEndReason.expired
          : LicenseEndReason.clockSetBack,
      validUntil: validUntil,
      noticedAt: now,
    );
  }

  /// What the activation screen shows about a license that stopped counting,
  /// or null when there is nothing to say (never licensed, or licensed and
  /// well). Works in the short gap before [backgroundVerify] has cleared an
  /// expired license too - the app is already on the activation screen then,
  /// and this answers from what is saved without changing anything.
  Future<LicenseEnd?> endedLicense() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      return await _isExpired(storage) ? _endFromSavedLicense(storage) : null;
    }
    // A joined device whose shop's license has run out: explained right away,
    // even before the background check has had a chance to record it.
    final recorded = await _readLastEnd(storage);
    final lease = await _advanceLease();
    if (lease != null && lease.isExpired) {
      return recorded?.reason == LicenseEndReason.shopLicenseExpired
          ? recorded
          : LicenseEnd(
              reason: LicenseEndReason.shopLicenseExpired,
              noticedAt: _ref.read(clockProvider).now(),
            );
    }
    return recorded;
  }

  Future<LicenseEnd?> _readLastEnd(FlutterSecureStorage storage) async {
    final raw = await storage.read(key: _lastEndKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LicenseEnd.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Deliberately does NOT delete _lastSeenKey - see
  /// _trackClockAndDetectRollback's doc for why that watermark must
  /// outlive any single license. [end] is written FIRST, so the activation
  /// screen it is about to lock the app onto already has something to say.
  Future<void> _clearLicense(
    FlutterSecureStorage storage, {
    LicenseEnd? end,
  }) async {
    if (end != null) {
      await storage.write(key: _lastEndKey, value: jsonEncode(end.toJson()));
    }
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _validUntilKey);
    _ref.invalidate(hasCachedLicenseProvider);
    _ref.read(licenseChangeSignalProvider.notifier).bump();
  }
}
