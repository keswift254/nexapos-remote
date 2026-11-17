import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/utils/money.dart';
import 'platform_http_client.dart';

/// "M-Pesa Till/Paybill": the shop's payment inbox on the platform (payment_inbox_* actions).
///
/// The customer pays the shop's OWN till or paybill. Safaricom's "payment received" SMS reaches the shop phone, which passes
/// it on to the platform (an iPhone through a Shortcut, set up from the Lite till's Settings > M-Pesa Till Phone). Any till
/// of the shop can then list what arrived and use a code on ONE sale - the platform refuses a code that never arrived, that
/// is for another amount, or that another sale already used.
final paymentInboxGatewayProvider = Provider<PaymentInboxGateway>((ref) => PaymentInboxGateway());

/// An M-Pesa code as a cashier may type it ("ukh3 r3nl-tu") in its stored form, or null when it cannot be one: 8 to 12
/// letters and numbers, with at least one of each. The platform's own rule.
String? normalizeMpesaCode(String typed) {
  final code = typed.replaceAll(RegExp(r'[\s\-]+'), '').toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{8,12}$').hasMatch(code)) return null;
  if (!RegExp('[A-Z]').hasMatch(code) || !RegExp('[0-9]').hasMatch(code)) return null;
  return code;
}

/// One M-Pesa code as the shop knows it: the message for it (if it arrived) and the sale it was used on (if any).
class TillPayment {
  const TillPayment({
    required this.code,
    required this.messageReceived,
    this.amount,
    this.payerName = '',
    this.payerPhone = '',
    this.accountRef = '',
    this.paidAtText = '',
    this.receivedAt,
    this.phoneLabel = '',
    this.usedOnSaleNumber,
    this.usedAmount,
    this.archivedAt,
  });

  final String code;

  /// True only when Safaricom's message for this code reached the shop (a code a cashier typed has none).
  final bool messageReceived;

  /// What the message says was paid; null when it could not be read.
  final Money? amount;
  final String payerName;
  final String payerPhone;
  final String accountRef;

  /// The payment time as the message says it ("18/11/26 1:05 PM"), when it could be read.
  final String paidAtText;

  /// When the message reached the shop (UTC).
  final DateTime? receivedAt;
  final String phoneLabel;

  /// The sale this code was used on, or null when it is still free.
  final String? usedOnSaleNumber;
  final Money? usedAmount;

  /// When the payment was archived: it is then no longer suggested at checkout (it stays in the shop's list, and its
  /// code can still be typed). Null when it never was.
  final DateTime? archivedAt;

  bool get isUsed => usedOnSaleNumber != null;

  bool get isArchived => archivedAt != null;

  factory TillPayment.fromJson(Map<String, dynamic> json) {
    final used = json['used'];
    return TillPayment(
      code: _text(json['code']),
      messageReceived: json['message_received'] == true,
      amount: _money(json['amount_cents']),
      payerName: _text(json['payer_name']),
      payerPhone: _text(json['payer_phone']),
      accountRef: _text(json['account_ref']),
      paidAtText: _text(json['paid_at_text']),
      receivedAt: _instant(json['received_at']),
      phoneLabel: _text(json['phone_label']),
      usedOnSaleNumber: used is Map ? _text(used['sale_number']) : null,
      usedAmount: used is Map ? _money(used['amount_cents']) : null,
      archivedAt: _instant(json['archived_at']),
    );
  }
}

String _text(Object? value) => value is String ? value.trim() : '';

/// Whole cents only: anything else (text, a fraction) is "unknown", never guessed.
Money? _money(Object? value) => value is int ? Money(value) : null;

DateTime? _instant(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim())?.toUtc();
}

/// What the platform said no to when a code was to be used on a sale.
class TillClaimRefused implements Exception {
  const TillClaimRefused(this.reason, this.message, {this.paidAmount});

  /// The platform's own word: `not_received`, `used`, `amount_differs`, `amount_unknown`, `bad_code`, `bad_request`,
  /// or `unavailable` when the platform does not know these actions yet (an older server).
  final String reason;
  final String message;

  /// For `amount_differs`: what the customer really paid.
  final Money? paidAmount;

  @override
  String toString() => message;
}

class PaymentInboxGateway {
  PaymentInboxGateway([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;

  /// What arrived (and what was used) in the last [hours] hours, newest first, and how many phones pass messages on.
  Future<({List<TillPayment> payments, int phones})> list({
    required String baseUrl,
    required String apiKey,
    int hours = 24,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await platformRequest(
        _client,
        'GET',
        'payment_inbox_list',
        baseUrl,
        apiKey: apiKey,
        queryParameters: {'hours': '${hours.clamp(1, 72)}'},
      );
    } on PaystackException catch (e) {
      throw _plain(e);
    }
    final rows = response['payments'];
    if (rows is! List) {
      throw const PaystackException('The shop server sent payments this device cannot read. Try again later.');
    }
    return (
      payments: [
        for (final row in rows)
          if (row is Map)
            TillPayment.fromJson(row.cast<String, dynamic>()),
      ].where((payment) => payment.code.isNotEmpty).toList(),
      phones: response['phones'] is int ? response['phones'] as int : 0,
    );
  }

  /// Uses [code] on the sale [saleId] / [saleNumber] of [amount]. Safaricom's message for the code must have arrived.
  /// [acceptAmount]: the cashier was told the customer paid another amount and goes ahead anyway.
  /// Throws [TillClaimRefused] when the platform says no, [PaystackOfflineException] without internet.
  Future<TillPayment> claim({
    required String baseUrl,
    required String apiKey,
    required String code,
    required String saleId,
    required String saleNumber,
    required Money amount,
    bool acceptAmount = false,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await platformRequest(
        _client,
        'POST',
        'payment_inbox_claim',
        baseUrl,
        apiKey: apiKey,
        body: {
          'code': code,
          'sale_id': saleId,
          'sale_number': saleNumber,
          'amount_cents': amount.cents,
          'require_message': true,
          'accept_amount': acceptAmount,
        },
      );
    } on PaystackException catch (e) {
      final body = e.body;
      final reason = body?['reason'];
      if (reason is String && reason.isNotEmpty) {
        throw TillClaimRefused(reason, e.message, paidAmount: _money(body?['amount_cents']));
      }
      if (e.statusCode == 404) {
        throw const TillClaimRefused('unavailable', 'The shop server cannot check M-Pesa payments yet. Ask the owner to update it.');
      }
      throw _plain(e);
    }
    final payment = response['payment'];
    if (response['success'] != true || payment is! Map) {
      throw const PaystackException('The shop server sent an answer this device cannot read.');
    }
    final read = TillPayment.fromJson(payment.cast<String, dynamic>());
    if (read.code != code) {
      throw const PaystackException('The shop server sent an answer this device cannot read.');
    }
    return read;
  }

  /// Archives a payment that arrived ([archived] true: it is no longer suggested at checkout, on any till of the shop) or
  /// suggests it again (false). Returns the payment as the shop now has it.
  Future<TillPayment> archive({
    required String baseUrl,
    required String apiKey,
    required String code,
    bool archived = true,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await platformRequest(
        _client,
        'POST',
        'payment_inbox_archive',
        baseUrl,
        apiKey: apiKey,
        body: {'code': code, 'archived': archived},
      );
    } on PaystackException catch (e) {
      if (e.body?['reason'] == 'not_found') {
        throw PaystackException('The shop has no M-Pesa payment with this code.', statusCode: e.statusCode, body: e.body);
      }
      throw _plain(e);
    }
    final payment = response['payment'];
    if (response['success'] != true || payment is! Map) {
      throw const PaystackException('The shop server sent an answer this device cannot read.');
    }
    final read = TillPayment.fromJson(payment.cast<String, dynamic>());
    if (read.code != code) {
      throw const PaystackException('The shop server sent an answer this device cannot read.');
    }
    return read;
  }

  /// Gives a code back (its sale was not saved after all). Best effort: a failure only leaves that code blocked.
  Future<void> release({
    required String baseUrl,
    required String apiKey,
    required String code,
    required String saleId,
  }) async {
    try {
      await platformRequest(
        _client,
        'POST',
        'payment_inbox_release',
        baseUrl,
        apiKey: apiKey,
        body: {'code': code, 'sale_id': saleId},
      );
    } catch (_) {
      // Nothing else to do: the code stays held for a sale that does not exist, and only that code is blocked.
    }
  }

  /// The platform's refusal in plain words for the cases every action shares.
  PaystackException _plain(PaystackException e) {
    if (e.statusCode == 404 && (e.body?['reason'] == null)) {
      return PaystackException('The shop server cannot do M-Pesa till payments yet. Ask the owner to update it.', statusCode: e.statusCode);
    }
    if ((e.statusCode == 401 || e.statusCode == 403) && e.body?['reason'] == null) {
      return PaystackException('This device is not allowed to do this. Ask the owner to check Connected devices.', statusCode: e.statusCode);
    }
    return e;
  }
}
