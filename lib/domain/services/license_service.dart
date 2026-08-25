import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../data/licensing/license_gateway.dart';

part 'license_service.g.dart';

const _tokenKey = 'nexapos.license.activationToken';
const _validUntilKey = 'nexapos.license.validUntil';
const _lastSeenKey = 'nexapos.license.lastSeenAt';
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
  return ref.watch(licenseServiceProvider).hasValidCachedLicense();
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

/// Online-activate-once, offline-run-forever: [activate] is the only
/// call that must succeed while online; after that the cached token
/// (plus an optional cached valid_until) alone gates the app, and
/// [backgroundVerify] just silently re-checks whenever internet happens
/// to be available. See nexapos-license-server memory doc for the full
/// design rationale.
class LicenseService {
  final Ref _ref;

  LicenseService(this._ref);

  Future<Result<void>> activate(String code) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) return const Result.failure('Enter your license key.');

    final deviceId = await _ref.read(syncMetadataProvider).deviceId();
    try {
      final result = await _ref.read(licenseGatewayProvider).activate(
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
      return const Result.failure('Could not reach the license server. Check your internet connection and try again.');
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
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return;

    if (await _isExpired(storage)) {
      await _clearLicense(storage);
      return;
    }

    try {
      final result = await _ref.read(licenseGatewayProvider).verify(
            baseUrl: licenseServerBaseUrl,
            activationToken: token,
          );
      if (!result.valid) {
        await _clearLicense(storage);
        return;
      }
      // Keeps the locally-cached deadline in sync with the server's -
      // covers a vendor-side revoke/extend that changed valid_until
      // without this device needing to reactivate.
      await _writeValidUntil(storage, result.validUntil);
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
    if (raw == null || raw.isEmpty) return false; // never expires - nothing to dodge, rollback is moot
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
  Future<bool> _trackClockAndDetectRollback(FlutterSecureStorage storage, DateTime now) async {
    final lastSeenRaw = await storage.read(key: _lastSeenKey);
    final lastSeen = lastSeenRaw != null && lastSeenRaw.isNotEmpty ? DateTime.tryParse(lastSeenRaw) : null;
    final rolledBack = lastSeen != null && lastSeen.difference(now) > _clockRollbackTolerance;
    if (lastSeen == null || now.isAfter(lastSeen)) {
      await storage.write(key: _lastSeenKey, value: now.toIso8601String());
    }
    return rolledBack;
  }

  Future<void> _writeValidUntil(FlutterSecureStorage storage, DateTime? validUntil) async {
    if (validUntil == null) {
      await storage.delete(key: _validUntilKey);
    } else {
      await storage.write(key: _validUntilKey, value: validUntil.toIso8601String());
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
