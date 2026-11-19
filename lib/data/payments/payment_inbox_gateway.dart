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

/// A phone that passes the shop's M-Pesa payment messages on (Settings > M-Pesa Till Phone). Its key is never listed.
class TillPhone {
  const TillPhone({
    required this.id,
    required this.label,
    this.addedBy = '',
    this.addedAt,
    this.lastMessageAt,
    this.senderCheck = false,
  });

  final int id;
  final String label;
  final String addedBy;
  final DateTime? addedAt;

  /// When this phone last passed a message on (any message, a payment or not); null when it never has.
  final DateTime? lastMessageAt;

  /// True once the phone's Shortcut passes on who each SMS came from: the shop then refuses a message a person typed and
  /// sent from their own number (only a literal true from the shop counts).
  final bool senderCheck;

  factory TillPhone.fromJson(Map<String, dynamic> json) => TillPhone(
        id: json['id'] is int ? json['id'] as int : 0,
        label: _text(json['label']),
        addedBy: _text(json['added_by']),
        addedAt: _instant(json['added_at']),
        lastMessageAt: _instant(json['last_message_at']),
        senderCheck: json['sender_check'] == true,
      );
}

List<TillPhone> _phones(Object? rows) => [
      if (rows is List)
        for (final row in rows)
          if (row is Map) TillPhone.fromJson(row.cast<String, dynamic>()),
    ].where((phone) => phone.id > 0).toList();

/// What setting a phone up gives back - ONCE: the shop keeps only a fingerprint of the key.
class TillPhoneKey {
  const TillPhoneKey({required this.key, required this.phone, required this.address});
  final String key;
  final TillPhone phone;

  /// Where the phone sends each message.
  final String address;

  /// The page the phone opens (by scanning a code) to be set up: the key goes after the #, which is never sent to a server.
  String get setupPageLink => 'https://nexapos.cc/lite/phone.html#k=$key';
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

  /// The shop's phones, and the most it may have.
  Future<({List<TillPhone> phones, int max})> phones({required String baseUrl, required String apiKey}) async {
    final Map<String, dynamic> response;
    try {
      response = await platformRequest(_client, 'GET', 'payment_inbox_sources', baseUrl, apiKey: apiKey);
    } on PaystackException catch (e) {
      throw _plain(e);
    }
    if (response['phones'] is! List) {
      throw const PaystackException('The shop server sent a list of phones this device cannot read. Try again later.');
    }
    final max = response['max_phones'];
    return (phones: _phones(response['phones']), max: max is int && max > 0 ? max : 5);
  }

  /// Sets a phone up. [userId] and [password] are the administrator's own: the SHOP checks them (whoever holds a key
  /// could pass on a made-up payment). The key comes back this once only.
  Future<TillPhoneKey> addPhone({
    required String baseUrl,
    required String apiKey,
    required String label,
    required String userId,
    required String password,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await platformRequest(
        _client,
        'POST',
        'payment_inbox_add_source',
        baseUrl,
        apiKey: apiKey,
        body: {'label': label, 'user_id': userId, 'password': password},
      );
    } on PaystackException catch (e) {
      throw _plain(e);
    }
    final key = response['key'];
    final phone = response['phone'];
    final read = phone is Map ? TillPhone.fromJson(phone.cast<String, dynamic>()) : null;
    if (key is! String || !RegExp(r'^npk_[a-f0-9]{48}$').hasMatch(key) || read == null || read.id <= 0) {
      throw const PaystackException(
          'The shop server sent a key this device cannot read. Remove the new phone from the list and set it up again.');
    }
    return TillPhoneKey(key: key, phone: read, address: '$baseUrl?action=payment_inbox_ingest');
  }

  /// Removes a phone (its key stops working at once). Same password rule as [addPhone]. Returns the phones left.
  Future<List<TillPhone>> removePhone({
    required String baseUrl,
    required String apiKey,
    required int phoneId,
    required String userId,
    required String password,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await platformRequest(
        _client,
        'POST',
        'payment_inbox_remove_source',
        baseUrl,
        apiKey: apiKey,
        body: {'phone_id': phoneId, 'user_id': userId, 'password': password},
      );
    } on PaystackException catch (e) {
      throw _plain(e);
    }
    return _phones(response['phones']);
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
