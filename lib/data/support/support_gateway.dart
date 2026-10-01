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
  });

  final int id;
  final String subject;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: _supportId(json['id']),
        subject: (json['subject'] as String? ?? '').trim(),
        status: (json['status'] as String? ?? 'open').trim(),
        createdAt: (json['created_at'] as String? ?? '').trim(),
        updatedAt: (json['updated_at'] as String? ?? '').trim(),
      );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String sender;
  final String body;
  final String createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: _supportId(json['id']),
        sender: (json['sender'] as String? ?? 'customer').trim(),
        body: (json['body'] as String? ?? '').trim(),
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
  Future<List<SupportTicket>> list({
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
    return [
      for (final item in (response['tickets'] as List? ?? const []))
        if (item is Map)
          SupportTicket.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<int> open({
    required String baseUrl,
    required String apiKey,
    required String subject,
    required String message,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'support_open',
      baseUrl,
      apiKey: apiKey,
      body: {'subject': subject, 'message': message},
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
    return SupportThread(
      ticket: SupportTicket.fromJson(rawTicket.cast<String, dynamic>()),
      messages: [
        for (final item in (response['messages'] as List? ?? const []))
          if (item is Map)
            SupportMessage.fromJson(item.cast<String, dynamic>()),
      ],
    );
  }

  Future<void> reply({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
    required String message,
  }) async {
    final response = await platformRequest(
      _client,
      'POST',
      'support_reply',
      baseUrl,
      apiKey: apiKey,
      body: {'ticket_id': ticketId, 'message': message},
    );
    if (response['success'] != true) {
      throw PaystackException(
        platformResponseMessage(response, 'Could not send your support message.'),
      );
    }
  }
}

final supportGatewayProvider = Provider<SupportGateway>((ref) => SupportGateway());
