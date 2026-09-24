import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const platformRequestTimeout = Duration(seconds: 25);

/// Sync isn't blocking a till transaction the way a Paystack charge is,
/// so it can afford to ride out a cold start on the Render-hosted
/// platform backend instead of timing out and forcing the cashier to
/// notice and press the refresh button again.
const platformSyncRequestTimeout = Duration(seconds: 55);

/// nexapos_platform now runs as a single central server this vendor
/// operates, same as nexapos_license (see license_gateway.dart's
/// licenseServerBaseUrl) - not something each shop self-hosts, which
/// was the original design before the move to a real multi-tenant SaaS
/// deployment. A compile-time constant rather than a field an operator
/// types in during registration; PaymentSettingsScreen no longer shows
/// that field at all. Update this if the deployment ever moves.
const nexaposPlatformBaseUrl =
    'https://nexapos-platform.onrender.com/index.php';

/// An error the payments-platform backend (or Paystack, relayed through
/// it) reported - bad/expired API key, declined transaction, malformed
/// request, a business rule rejection (e.g. "settle before charging").
/// Surface [message] to the user as-is.
class PaystackException implements Exception {
  final String message;
  final int? statusCode;
  const PaystackException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Distinguished from [PaystackException] so callers can map this
/// specific case to a "needs internet" / "can't reach the server"
/// message instead of a raw socket/timeout error.
class PaystackOfflineException implements Exception {
  /// True when the server WAS reachable but did not answer within the
  /// timeout (a slow or waking-up server), as opposed to no connection at
  /// all. The two need different words: telling a cashier "offline" while
  /// their internet is fine sends them off to fix the wrong thing.
  final bool timedOut;
  const PaystackOfflineException({this.timedOut = false});
}

const _httpMonths = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

/// Reads an HTTP `Date` header ("Thu, 24 Sep 2026 12:00:00 GMT") as UTC, or
/// null when it is missing or not in that form. Written by hand rather than
/// with dart:io's HttpDate, which the browser build cannot use.
DateTime? parseHttpDate(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^\w{3}, (\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final month = _httpMonths[match.group(2)];
  if (month == null) return null;
  try {
    return DateTime.utc(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  } catch (_) {
    return null;
  }
}

/// Shared request/error-mapping plumbing for talking to the operator's
/// payments-platform backend (see paystack_gateway.dart's class doc for
/// why the phone talks to that backend instead of Paystack directly).
/// Used by both PaystackGateway (checkout-time) and
/// PlatformOnboardingGateway (setup-time) so the two stay separate
/// classes with separate public APIs without duplicating this part.
///
/// [onServerTime], when given, is told the server's own clock from the
/// response's `Date` header - the only source of the real time this device
/// has that its owner cannot change from the date-and-time settings (see
/// LicenseService and TrustedTimeService). Not called when the response has
/// no readable `Date` header (a browser hides it from cross-origin pages).
Future<Map<String, dynamic>> platformRequest(
  http.Client client,
  String method,
  String action,
  String baseUrl, {
  String? apiKey,
  Map<String, dynamic>? body,
  Map<String, String>? queryParameters,
  Duration timeout = platformRequestTimeout,
  void Function(DateTime serverTime)? onServerTime,
}) async {
  final uri = Uri.parse(baseUrl)
      .replace(queryParameters: {'action': action, ...?queryParameters});
  final headers = {
    'Accept': 'application/json',
    if (apiKey != null) 'Authorization': 'Bearer ${apiKey.trim()}',
    if (body != null) 'Content-Type': 'application/json',
  };

  http.Response response;
  try {
    response =
        await (method == 'POST'
                ? client.post(uri, headers: headers, body: jsonEncode(body))
                : client.get(uri, headers: headers))
            .timeout(timeout);
  } on TimeoutException {
    throw const PaystackOfflineException(timedOut: true);
  } on SocketException {
    throw const PaystackOfflineException();
  } on http.ClientException {
    throw const PaystackOfflineException();
  }

  if (onServerTime != null) {
    final serverTime = parseHttpDate(response.headers['date']);
    if (serverTime != null) onServerTime(serverTime);
  }

  // A non-JSON body (an HTML error page from a PHP fatal error, a proxy
  // timeout page, or an empty response) must not escape as a raw
  // FormatException - callers like PaystackPaymentService.poll() only
  // catch PaystackException/PaystackOfflineException by type, so an
  // uncaught FormatException here would propagate out of a polling
  // Timer's callback uncaught.
  Object? decoded;
  try {
    decoded = jsonDecode(response.body);
  } on FormatException {
    throw const PaystackException(
      'The payments server sent back an invalid response.',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const PaystackException(
      'The payments server sent back an invalid response.',
    );
  }
  if (response.statusCode >= 400) {
    throw PaystackException(
      platformResponseMessage(
        decoded,
        'The payments server rejected the request.',
      ),
      statusCode: response.statusCode,
    );
  }
  return decoded;
}

String platformResponseMessage(Map<String, dynamic> response, String fallback) {
  final message = response['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  final data = response['data'];
  if (data is Map) {
    final gatewayResponse = data['gateway_response'];
    if (gatewayResponse is String && gatewayResponse.trim().isNotEmpty) {
      return gatewayResponse.trim();
    }
  }
  return fallback;
}
