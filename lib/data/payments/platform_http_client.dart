import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const platformRequestTimeout = Duration(seconds: 25);

/// nexapos_platform now runs as a single central server this vendor
/// operates, same as nexapos_license (see license_gateway.dart's
/// licenseServerBaseUrl) - not something each shop self-hosts, which
/// was the original design before the move to a real multi-tenant SaaS
/// deployment. A compile-time constant rather than a field an operator
/// types in during registration; PaymentSettingsScreen no longer shows
/// that field at all. Update this if the deployment ever moves.
const nexaposPlatformBaseUrl = 'https://nexapos-platform.onrender.com/index.php';

/// An error the payments-platform backend (or Paystack, relayed through
/// it) reported - bad/expired API key, declined transaction, malformed
/// request, a business rule rejection (e.g. "settle before charging").
/// Surface [message] to the user as-is.
class PaystackException implements Exception {
  final String message;
  const PaystackException(this.message);

  @override
  String toString() => message;
}

/// Distinguished from [PaystackException] so callers can map this
/// specific case to a "needs internet" / "can't reach the server"
/// message instead of a raw socket/timeout error.
class PaystackOfflineException implements Exception {
  const PaystackOfflineException();
}

/// Shared request/error-mapping plumbing for talking to the operator's
/// payments-platform backend (see paystack_gateway.dart's class doc for
/// why the phone talks to that backend instead of Paystack directly).
/// Used by both PaystackGateway (checkout-time) and
/// PlatformOnboardingGateway (setup-time) so the two stay separate
/// classes with separate public APIs without duplicating this part.
Future<Map<String, dynamic>> platformRequest(
  http.Client client,
  String method,
  String action,
  String baseUrl, {
  String? apiKey,
  Map<String, dynamic>? body,
  Map<String, String>? queryParameters,
}) async {
  final uri = Uri.parse(baseUrl).replace(queryParameters: {
    'action': action,
    ...?queryParameters,
  });
  final headers = {
    'Accept': 'application/json',
    if (apiKey != null) 'Authorization': 'Bearer ${apiKey.trim()}',
    if (body != null) 'Content-Type': 'application/json',
  };

  http.Response response;
  try {
    response = await (method == 'POST'
            ? client.post(uri, headers: headers, body: jsonEncode(body))
            : client.get(uri, headers: headers))
        .timeout(platformRequestTimeout);
  } on TimeoutException {
    throw const PaystackOfflineException();
  } on SocketException {
    throw const PaystackOfflineException();
  } on http.ClientException {
    throw const PaystackOfflineException();
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
    throw const PaystackException('The payments server sent back an invalid response.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const PaystackException('The payments server sent back an invalid response.');
  }
  if (response.statusCode >= 400) {
    throw PaystackException(platformResponseMessage(decoded, 'The payments server rejected the request.'));
  }
  return decoded;
}

String platformResponseMessage(Map<String, dynamic> response, String fallback) {
  final message = response['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  final data = response['data'];
  if (data is Map) {
    final gatewayResponse = data['gateway_response'];
    if (gatewayResponse is String && gatewayResponse.trim().isNotEmpty) return gatewayResponse.trim();
  }
  return fallback;
}
