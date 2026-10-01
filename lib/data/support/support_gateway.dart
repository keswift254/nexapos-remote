import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../payments/platform_http_client.dart';

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.customerEmail,
    this.lastSupportMessageId = 0,
  });

  final int id;
  final String subject;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? customerEmail;
  final int lastSupportMessageId;
  String get replyToken => '$id:${lastSupportMessageId == 0 ? updatedAt : lastSupportMessageId}';

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: _supportId(json['id']),
        subject: (json['subject'] as String? ?? '').trim(),
        status: (json['status'] as String? ?? 'open').trim(),
        createdAt: (json['created_at'] as String? ?? '').trim(),
        updatedAt: (json['updated_at'] as String? ?? '').trim(),
        customerEmail: (json['customer_email'] as String?)?.trim(),
        lastSupportMessageId: int.tryParse('${json['last_support_message_id'] ?? 0}') ?? 0,
      );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.attachments = const [],
  });

  final int id;
  final String sender;
  final String body;
  final List<int> attachments;
  final String createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: _supportId(json['id']),
        sender: (json['sender'] as String? ?? 'customer').trim(),
        body: (json['body'] as String? ?? '').trim(),
        attachments: [for (final a in (json['attachments'] as List? ?? const [])) _supportId((a as Map)['id'])],
        createdAt: (json['created_at'] as String? ?? '').trim(),
      );
}

int _supportId(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final id = int.tryParse(value);
    if (id != null) return id;
  }
  throw const FormatException('Invalid support ticket ID.');
}

class SupportThread {
  const SupportThread({required this.ticket, required this.messages});
  final SupportTicket ticket;
  final List<SupportMessage> messages;
}

class SupportGateway {
  SupportGateway([http.Client? client]) : _client = client ?? http.Client();
  final http.Client _client;
  final _lists = <String, List<SupportTicket>>{};
  final _requests = <String, Future<List<SupportTicket>>>{};
  final _threads = <String, SupportThread>{};
  String _key(String baseUrl, String apiKey) => '$baseUrl|$apiKey';
  List<SupportTicket>? cachedList(String baseUrl, String apiKey) => _lists[_key(baseUrl, apiKey)];
  SupportThread? cachedThread(String baseUrl, String apiKey, int id) => _threads['${_key(baseUrl, apiKey)}|$id'];

  Future<Uint8List> photo({required String baseUrl, required String apiKey, required int id}) async {
    final response = await _client.get(Uri.parse(baseUrl).replace(queryParameters: {'action': 'support_attachment', 'id': '$id'}),
        headers: {'Authorization': 'Bearer ${apiKey.trim()}'}).timeout(platformRequestTimeout);
    if (response.statusCode != 200 || !(response.headers['content-type'] ?? '').startsWith('image/')) {
      throw const PaystackException('Could not load this photo.');
    }
    return response.bodyBytes;
  }

  Future<List<SupportTicket>> list({required String baseUrl, required String apiKey}) {
    final key = _key(baseUrl, apiKey);
    return _requests.putIfAbsent(key, () => _fetchList(baseUrl: baseUrl, apiKey: apiKey)
      .whenComplete(() => _requests.remove(key)));
  }

  Future<List<SupportTicket>> _fetchList({
    required String baseUrl,
    required String apiKey,
  }) async {
    final response = await platformRequest(
      _client,
      'GET',
      'support_list',
      baseUrl,
      apiKey: apiKey,
    );
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not load support tickets.'),
      );
    }
    final tickets = [
      for (final item in (response['tickets'] as List? ?? const []))
        if (item is Map)
          SupportTicket.fromJson(item.cast<String, dynamic>()),
    ];
    if (_lists.length > 4) _lists.clear();
    _lists[_key(baseUrl, apiKey)] = tickets;
    return tickets;
  }

  Future<int> open({
    required String baseUrl,
    required String apiKey,
    required String subject,
    required String message,
    String? email,
    List<Uint8List> photos = const [],
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'support_open',
      baseUrl,
      apiKey: apiKey,
      body: {
        'subject': subject,
        'message': message,
        if (photos.isNotEmpty) 'attachments': [for (final p in photos) {'data': base64Encode(p)}],
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not open the support ticket.'),
      );
    }
    return _supportId(response['ticket_id']);
  }

  Future<SupportThread> thread({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
  }) async {
    final response = await platformRequest(
      _client,
      'GET',
      'support_thread',
      baseUrl,
      apiKey: apiKey,
      queryParameters: {'ticket_id': '$ticketId'},
    );
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not load this support ticket.'),
      );
    }
    final rawTicket = response['ticket'];
    if (rawTicket is! Map) {
      throw const PaystackException('The support server returned an invalid ticket.');
    }
    final thread = SupportThread(
      ticket: SupportTicket.fromJson(rawTicket.cast<String, dynamic>()),
      messages: [
        for (final item in (response['messages'] as List? ?? const []))
          if (item is Map)
            SupportMessage.fromJson(item.cast<String, dynamic>()),
      ],
    );
    if (_threads.length > 20) _threads.clear();
    _threads['${_key(baseUrl, apiKey)}|$ticketId'] = thread;
    return thread;
  }

  Future<void> reply({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
    required String message,
    List<Uint8List> photos = const [],
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'support_reply',
      baseUrl,
      apiKey: apiKey,
      body: {'ticket_id': ticketId, 'message': message,
        if (photos.isNotEmpty) 'attachments': [for (final p in photos) {'data': base64Encode(p)}]},
    );
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not send your support message.'),
      );
    }
  }

  Future<void> close({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'support_close',
      baseUrl,
      apiKey: apiKey,
      body: {'ticket_id': ticketId},
    );
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not close this ticket.'),
      );
    }
  }
}

final supportGatewayProvider = Provider<SupportGateway>((ref) => SupportGateway());
