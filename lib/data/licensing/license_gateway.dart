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

  /// The license server's own clock when it answered (its HTTP `Date`
  /// header) - real time that does not depend on this device's date.
  final DateTime? serverTime;
  const ActivationResult({
    required this.token,
    this.validUntil,
    this.serverTime,
  });
}

class VerificationResult {
  final bool valid;
  final DateTime? validUntil;
  final int authenticatorGeneration;

  /// See [ActivationResult.serverTime].
  final DateTime? serverTime;
  const VerificationResult({
    required this.valid,
    this.validUntil,
    this.authenticatorGeneration = 0,
    this.serverTime,
  });
}

/// One thing a license can be bought as. The SERVER decides what plans exist,
/// what they cost and how long they last - the app only shows what it is told,
/// and the amount that is charged is never one it sends.
class PurchasePlan {
  final String id;
  final String label;
  final int months;
  final int amountKes;
  const PurchasePlan({
    required this.id,
    required this.label,
    required this.months,
    required this.amountKes,
  });

  static PurchasePlan? fromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final id = decoded['id'];
    final label = decoded['label'];
    final months = decoded['months'];
    final amount = decoded['amount_kes'];
    if (id is! String || id.isEmpty || label is! String) return null;
    if (months is! num || months < 1 || amount is! num || amount < 1) {
      return null;
    }
    return PurchasePlan(
      id: id,
      label: label,
      months: months.toInt(),
      amountKes: amount.toInt(),
    );
  }
}

class PlanCatalog {
  /// False until the vendor's payment account is set up on the server: the
  /// plans are still listed, but cannot be paid for yet.
  final bool purchasingEnabled;
  final List<PurchasePlan> plans;
  const PlanCatalog({required this.purchasingEnabled, required this.plans});
}

/// What starting a purchase gives back: where the customer pays, and the
/// reference the app then asks about.
class CheckoutStart {
  final String reference;
  final Uri paymentUrl;
  final PurchasePlan? plan;
  const CheckoutStart({
    required this.reference,
    required this.paymentUrl,
    this.plan,
  });
}

enum PurchaseState { pending, issued, failed }

class PurchaseStatus {
  final PurchaseState state;

  /// The license key, once [state] is issued.
  final String? code;
  final String? message;
  const PurchaseStatus({required this.state, this.code, this.message});
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

  Future<ActivationResult> activate({
    required String baseUrl,
    required String code,
    required String deviceId,
  }) async {
    DateTime? serverTime;
    final response = await _call(
      'POST',
      'activate',
      baseUrl,
      body: {'code': code, 'device_id': deviceId},
      onServerTime: (t) => serverTime = t,
    );
    if (response['success'] != true) {
      throw LicenseException(
        platformResponseMessage(
          response,
          'Could not activate this license key.',
        ),
      );
    }
    final token = (response['activation_token'] as String? ?? '').trim();
    if (token.isEmpty) {
      throw const LicenseException(
        'The license server did not return an activation token.',
      );
    }
    return ActivationResult(
      token: token,
      validUntil: _parseUtc(response['valid_until']),
      serverTime: serverTime,
    );
  }

  Future<VerificationResult> verify({
    required String baseUrl,
    required String activationToken,
  }) async {
    DateTime? serverTime;
    final response = await _call(
      'POST',
      'verify',
      baseUrl,
      bearerToken: activationToken,
      onServerTime: (t) => serverTime = t,
    );
    if (response['success'] != true) {
      throw LicenseException(
        platformResponseMessage(response, 'Could not verify this license.'),
      );
    }
    return VerificationResult(
      valid: response['valid'] == true,
      validUntil: _parseUtc(response['valid_until']),
      authenticatorGeneration: response['authenticator_generation'] is int
          ? response['authenticator_generation'] as int
          : 0,
      serverTime: serverTime,
    );
  }

  /// What is for sale. Public and read-only; needs no device or key.
  Future<PlanCatalog> fetchPlans({required String baseUrl}) async {
    final response = await _call('GET', 'plans', baseUrl);
    if (response['success'] != true) {
      throw LicenseException(
        platformResponseMessage(response, 'Could not load the plans.'),
      );
    }
    final plans = <PurchasePlan>[
      for (final raw in (response['plans'] as List? ?? const []))
        ?PurchasePlan.fromJson(raw),
    ];
    return PlanCatalog(
      purchasingEnabled: response['purchasing_enabled'] == true,
      plans: plans,
    );
  }

  /// Asks the server for a checkout page for [planId]. The server works out the
  /// price; the app only says which plan, for which device, and where the
  /// receipt goes.
  Future<CheckoutStart> startCheckout({
    required String baseUrl,
    required String deviceId,
    required String planId,
    required String email,
  }) async {
    final response = await _call(
      'POST',
      'checkout_start',
      baseUrl,
      body: {'device_id': deviceId, 'plan_id': planId, 'email': email},
    );
    if (response['success'] != true) {
      throw LicenseException(
        platformResponseMessage(response, 'Could not start the payment.'),
      );
    }
    final reference = (response['reference'] as String? ?? '').trim();
    final url = Uri.tryParse((response['authorization_url'] as String? ?? '').trim());
    // Only ever a secure page: this is where a person is about to type card or
    // M-Pesa details.
    if (reference.isEmpty || url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const LicenseException(
        'The payment page could not be opened. Try again, or contact NexaPOS.',
      );
    }
    return CheckoutStart(
      reference: reference,
      paymentUrl: url,
      plan: PurchasePlan.fromJson(response['plan']),
    );
  }

  /// Has this purchase been paid for? Once it has, the license key comes back
  /// here (the same key every time it is asked).
  Future<PurchaseStatus> checkoutStatus({
    required String baseUrl,
    required String reference,
    required String deviceId,
  }) async {
    final response = await _call(
      'POST',
      'checkout_status',
      baseUrl,
      body: {'reference': reference, 'device_id': deviceId},
    );
    if (response['success'] != true) {
      throw LicenseException(
        platformResponseMessage(response, 'Could not check the payment.'),
      );
    }
    final code = (response['code'] as String? ?? '').trim();
    switch (response['status']) {
      case 'issued':
        if (code.isEmpty) {
          throw const LicenseException('The server did not send the license key.');
        }
        return PurchaseStatus(state: PurchaseState.issued, code: code);
      case 'failed':
        return PurchaseStatus(
          state: PurchaseState.failed,
          message: response['message'] as String?,
        );
      default:
        return const PurchaseStatus(state: PurchaseState.pending);
    }
  }

  Future<void> redeemSupport({
    required String baseUrl,
    required String activationToken,
    required String deviceId,
    required String password,
  }) async {
    final response = await _call(
      'POST',
      'redeem_support_access',
      baseUrl,
      bearerToken: activationToken,
      body: {'device_id': deviceId, 'password': password},
    );
    if (response['success'] != true) {
      throw const LicenseException('Support access was not authorized.');
    }
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String action,
    String baseUrl, {
    String? bearerToken,
    Map<String, dynamic>? body,
    void Function(DateTime serverTime)? onServerTime,
  }) async {
    try {
      return await platformRequest(
        _client,
        method,
        action,
        baseUrl,
        apiKey: bearerToken,
        body: body,
        onServerTime: onServerTime,
      );
    } on PaystackOfflineException {
      throw const LicenseOfflineException();
    } on PaystackException catch (e) {
      throw LicenseException(e.message);
    }
  }
}
