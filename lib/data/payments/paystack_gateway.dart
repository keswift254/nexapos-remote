import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/is_web.dart';
import '../../core/utils/money.dart';
import 'platform_http_client.dart';

export 'platform_http_client.dart' show PaystackException, PaystackOfflineException;

part 'paystack_gateway.g.dart';

@Riverpod(keepAlive: true)
PaystackGateway paystackGateway(Ref ref) => PaystackGateway();

class PaystackInitResult {
  final String authorizationUrl;
  final String reference;

  const PaystackInitResult({required this.authorizationUrl, required this.reference});
}

class PaystackVerifyResult {
  final bool success;
  final String message;
  final String reference;

  const PaystackVerifyResult({required this.success, required this.message, required this.reference});
}

/// Thin HTTP client for the operator's own payments-platform backend -
/// NOT Paystack directly. This device never holds a Paystack secret
/// key; [apiKey] is a token that backend issued to this specific device
/// (see PlatformOnboardingGateway.registerDevice), and every call here
/// is the backend proxying to Paystack using its own platform key.
/// Response shapes for initialize/verify are deliberately Paystack's
/// own envelope, relayed verbatim by the backend, so the parsing logic
/// below is unchanged from when this class called api.paystack.co
/// directly - only the request side (URL, auth) changed.
class PaystackGateway {
  final http.Client _client;
  final bool _web;

  /// [forWeb] exists for tests (the VM never runs as a browser); the app
  /// always takes the real platform.
  PaystackGateway([http.Client? client, bool? forWeb])
      : _client = client ?? http.Client(),
        _web = forWeb ?? isWeb;

  Future<PaystackInitResult> initialize({
    required String baseUrl,
    required String apiKey,
    required Money amount,
    required String reference,
    required String email,
    required String currency,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'initialize_transaction',
      baseUrl,
      apiKey: apiKey,
      body: {
        'email': email,
        'amount': amount.cents,
        'currency': currency,
        'reference': reference,
        // Where Paystack sends the customer afterwards. Native builds come
        // back through a nexapos:// link. The web POS (a browser tab or an
        // iPhone Home Screen app) is handed to its own return page, which
        // tells a waiting NexaPOS tab to check the payment straight away or,
        // if the app was reloaded meanwhile, reopens it. The server only
        // accepts these fixed choices, never a URL from here. A server that
        // predates return_to ignores it and behaves as before.
        'return_to_app': !_web,
        if (_web) 'return_to': 'web',
      },
    );
    if (response['status'] != true) {
      throw PaystackException(platformResponseMessage(response, 'Paystack transaction was not initialized.'));
    }
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final url = (data['authorization_url'] as String? ?? '').trim();
    final ref = (data['reference'] as String? ?? reference).trim();
    if (url.isEmpty) throw const PaystackException('The payment processor did not return a checkout URL.');
    return PaystackInitResult(authorizationUrl: url, reference: ref);
  }

  Future<PaystackVerifyResult> verify({
    required String baseUrl,
    required String apiKey,
    required String reference,
    required Money expectedAmount,
    required String currency,
  }) async {
    final response = await platformRequest(
      _client,
      'GET',
      'verify_transaction',
      baseUrl,
      apiKey: apiKey,
      queryParameters: {'reference': reference},
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final status = (data['status'] as String? ?? '').toLowerCase().trim();
    final paidAmount = (data['amount'] as num? ?? 0).toInt();
    final responseCurrency = (data['currency'] as String? ?? currency).toUpperCase().trim();
    final success = response['status'] == true &&
        status == 'success' &&
        paidAmount == expectedAmount.cents &&
        responseCurrency == currency.toUpperCase();
    return PaystackVerifyResult(
      success: success,
      message: success ? 'Payment received.' : platformResponseMessage(response, 'Payment was not successful.'),
      reference: (data['reference'] as String? ?? reference).trim(),
    );
  }
}
