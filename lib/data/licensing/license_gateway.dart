import 'package:http/http.dart' as http;
import '../payments/platform_http_client.dart';

/// nexapos_license runs as a single central server this vendor operates
/// (unlike nexapos_platform's baseUrl, which each shop configures for
/// its own self-hosted instance during onboarding) - so the address is
/// a compile-time constant rather than something typed in during setup.
/// Deployed 2026-08-23 to Render - note the "-1" suffix: "nexapos-license"
/// alone was already taken on Render's global .onrender.com namespace, so
/// this is the real assigned hostname, not a typo.
const licenseServerBaseUrl = 'https://nexapos-license-1.onrender.com/index.php';

class LicenseException implements Exception {
  final String message;
  const LicenseException(this.message);

  @override
  String toString() => message;
}

/// Distinguished from [LicenseException] so callers can treat "couldn't
/// reach the server" as "keep running on the cached activation" instead
/// of a hard denial - see LicenseService.backgroundVerify.
class LicenseOfflineException implements Exception {
  const LicenseOfflineException();
}

class ActivationResult {
  final String token;
  final DateTime? validUntil;
  const ActivationResult({required this.token, this.validUntil});
}

class VerificationResult {
  final bool valid;
  final DateTime? validUntil;
  const VerificationResult({required this.valid, this.validUntil});
}

/// license_keys.valid_until is a MySQL TIMESTAMP string ("2026-09-22
/// 17:44:05", written via UTC_TIMESTAMP()) with no zone marker - handing
/// that straight to DateTime.parse would interpret it in the device's
/// LOCAL timezone, not UTC (the same class of bug the server side hit
/// once already with strtotime(), see index.php's activate() comment).
/// Mirrors generator.html's identical fix: force a 'Z' onto it.
DateTime? _parseUtc(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.parse('${raw.replaceFirst(' ', 'T')}Z');
}

/// Talks to nexapos_license's activate/verify endpoints. Reuses
/// platform_http_client's request/timeout/JSON-decoding plumbing (the
/// same helper PlatformOnboardingGateway uses) rather than
/// reimplementing it - that file already got the Socket-timeout and
/// malformed-JSON edge cases right once; only the exception types are
/// translated at this boundary so callers don't have to catch
/// Paystack-named exceptions from licensing code.
class LicenseGateway {
  final http.Client _client;

  LicenseGateway([http.Client? client]) : _client = client ?? http.Client();

  Future<ActivationResult> activate({required String baseUrl, required String code, required String deviceId}) async {
    final response = await _call(
      'POST',
      'activate',
      baseUrl,
      body: {'code': code, 'device_id': deviceId},
    );
    if (response['success'] != true) {
      throw LicenseException(platformResponseMessage(response, 'Could not activate this license key.'));
    }
    final token = (response['activation_token'] as String? ?? '').trim();
    if (token.isEmpty) {
      throw const LicenseException('The license server did not return an activation token.');
    }
    return ActivationResult(token: token, validUntil: _parseUtc(response['valid_until']));
  }

  Future<VerificationResult> verify({required String baseUrl, required String activationToken}) async {
    final response = await _call('POST', 'verify', baseUrl, bearerToken: activationToken);
    if (response['success'] != true) {
      throw LicenseException(platformResponseMessage(response, 'Could not verify this license.'));
    }
    return VerificationResult(valid: response['valid'] == true, validUntil: _parseUtc(response['valid_until']));
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String action,
    String baseUrl, {
    String? bearerToken,
    Map<String, dynamic>? body,
  }) async {
    try {
      return await platformRequest(_client, method, action, baseUrl, apiKey: bearerToken, body: body);
    } on PaystackOfflineException {
      throw const LicenseOfflineException();
    } on PaystackException catch (e) {
      throw LicenseException(e.message);
    }
  }
}
