import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A scripted stand-in for the license server's buy-a-license actions (plans,
/// checkout_start, checkout_status) plus activate, for tests. What each call
/// answers is set by the test; every call is counted and recorded.
class FakeLicenseServer {
  bool offline = false;
  bool purchasingEnabled = true;
  List<Map<String, dynamic>> plans = [
    {'id': 'm3', 'label': '3 months', 'months': 3, 'amount_kes': 1500},
    {'id': 'm6', 'label': '6 months', 'months': 6, 'amount_kes': 3000},
    {'id': 'm12', 'label': '1 year', 'months': 12, 'amount_kes': 4800},
  ];

  /// Overrides the answer to checkout_start (e.g. a 429 or 503).
  http.Response? startAnswer;
  String reference = 'nxl-test0001';
  String paymentUrl = 'https://checkout.paystack.com/test0001';

  /// What checkout_status answers, one per call in order; the LAST one repeats.
  /// A Map is a 200 JSON answer; an http.Response is sent as is; an Exception is thrown.
  List<Object> statusScript = [
    {'success': true, 'status': 'pending'},
  ];

  /// Overrides the answer to activate (default: success).
  http.Response? activateAnswer;

  int plansCalls = 0;
  int startCalls = 0;
  int statusCalls = 0;
  int activateCalls = 0;
  Map<String, dynamic>? lastStart;
  final List<String> activatedCodes = [];

  static const licenseCode = 'PAID234567';

  http.Client get client => MockClient(_handle);

  http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status);

  Future<http.Response> _handle(http.Request request) async {
    if (offline) throw const SocketException('no internet');
    final action = request.url.queryParameters['action'];
    final Map<String, dynamic> body = request.body.isEmpty
        ? const {}
        : (jsonDecode(request.body) as Map).cast<String, dynamic>();
    switch (action) {
      case 'plans':
        plansCalls++;
        return _json({'success': true, 'purchasing_enabled': purchasingEnabled, 'currency': 'KES', 'plans': plans});
      case 'checkout_start':
        startCalls++;
        lastStart = body;
        final answer = startAnswer;
        if (answer != null) return answer;
        final plan = plans.firstWhere((p) => p['id'] == body['plan_id'], orElse: () => plans.first);
        return _json({'success': true, 'reference': reference, 'authorization_url': paymentUrl, 'plan': plan});
      case 'checkout_status':
        statusCalls++;
        final next = statusScript.length > 1 ? statusScript.removeAt(0) : statusScript.first;
        if (next is Exception) throw next;
        if (next is http.Response) return next;
        return _json(next as Map<String, dynamic>);
      case 'activate':
        activateCalls++;
        activatedCodes.add(body['code'] as String? ?? '');
        return activateAnswer ??
            _json({'success': true, 'activation_token': 'a' * 64, 'valid_until': '2027-03-25 10:00:00'});
    }
    return _json({'success': false, 'message': 'Unknown action.'}, 404);
  }
}
