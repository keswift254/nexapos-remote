import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/utils/money.dart';
import 'platform_http_client.dart';

export 'platform_http_client.dart' show PaystackException, PaystackOfflineException;

part 'intasend_gateway.g.dart';

@Riverpod(keepAlive: true)
IntaSendGateway intaSendGateway(Ref ref) => IntaSendGateway();

class IntaSendCollectResult {
  final String reference;
  final String invoiceId;

  const IntaSendCollectResult({required this.reference, required this.invoiceId});
}

class IntaSendVerifyResult {
  final bool success;
  final String message;
  final String reference;

  const IntaSendVerifyResult({required this.success, required this.message, required this.reference});
}

/// Thin HTTP client for the operator's own payments-platform backend,
/// same shared backend and same device Bearer token as PaystackGateway
/// (see that class's doc) - this device never holds an IntaSend key
/// either. The backend normalizes IntaSend's own response shape into the
/// exact same {status, data: {status, amount, currency, reference}}
/// envelope Paystack's verify_transaction already returns, so verify()
/// below is intentionally near-identical to PaystackGateway.verify().
class IntaSendGateway {
  final http.Client _client;

  IntaSendGateway([http.Client? client]) : _client = client ?? http.Client();

  Future<IntaSendCollectResult> collect({
    required String baseUrl,
    required String apiKey,
    required Money amount,
    required String reference,
    required String phoneNumber,
    String? name,
    String? email,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'intasend_collect',
      baseUrl,
      apiKey: apiKey,
      body: {
        'amount': amount.cents,
        'reference': reference,
        'phone_number': phoneNumber,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    if (response['status'] != true) {
      throw PaystackException(platformResponseMessage(response, 'IntaSend did not accept the request.'));
    }
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final invoiceId = (data['invoice_id'] as String? ?? '').trim();
    final ref = (data['reference'] as String? ?? reference).trim();
    if (invoiceId.isEmpty) throw const PaystackException('IntaSend did not return a tracking id.');
    return IntaSendCollectResult(reference: ref, invoiceId: invoiceId);
  }

  Future<IntaSendVerifyResult> verify({
    required String baseUrl,
    required String apiKey,
    required String reference,
    required Money expectedAmount,
  }) async {
    final response = await platformRequest(
      _client,
      'GET',
      'intasend_status',
      baseUrl,
      apiKey: apiKey,
      queryParameters: {'reference': reference},
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final status = (data['status'] as String? ?? '').toLowerCase().trim();
    final paidAmount = (data['amount'] as num? ?? 0).toInt();
    final success = response['status'] == true && status == 'success' && paidAmount == expectedAmount.cents;
    return IntaSendVerifyResult(
      success: success,
      message: success ? 'IntaSend payment received.' : platformResponseMessage(response, 'IntaSend payment was not successful.'),
      reference: (data['reference'] as String? ?? reference).trim(),
    );
  }
}
