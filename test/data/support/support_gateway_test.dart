import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/support/support_gateway.dart';

void main() {
  test('reads support IDs returned as strings by MySQL/PHP', () async {
    final gateway = SupportGateway(MockClient((request) async {
      switch (request.url.queryParameters['action']) {
        case 'support_list':
          return http.Response(jsonEncode({
            'success': true,
            'tickets': [
              {
                'id': '42',
                'subject': 'Printer issue',
                'status': 'open',
                'created_at': '2026-10-01 12:00:00',
                'updated_at': '2026-10-01 12:00:00',
              },
            ],
          }), 200);
        case 'support_thread':
          expect(request.url.queryParameters['ticket_id'], '42');
          return http.Response(jsonEncode({
            'success': true,
            'ticket': {
              'id': '42',
              'subject': 'Printer issue',
              'status': 'open',
            },
            'messages': [
              {'id': '99', 'sender': 'customer', 'body': 'Help', 'created_at': '2026-10-01 12:00:00'},
            ],
          }), 200);
        default:
          fail('Unexpected action: ${request.url.queryParameters['action']}');
      }
    }));

    final tickets = await gateway.list(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'test-key',
    );
    expect(tickets.single.id, 42);
    final thread = await gateway.thread(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'test-key',
      ticketId: tickets.single.id,
    );
    expect(thread.ticket.id, 42);
    expect(thread.messages.single.id, 99);
  });

  test('sends an optional contact email and closes a shop ticket', () async {
    final actions = <String>[];
    final gateway = SupportGateway(MockClient((request) async {
      final action = request.url.queryParameters['action']!;
      actions.add(action);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (action == 'support_open') {
        expect(body['email'], 'owner@example.com');
        expect(body['subject'], 'Printer issue');
        return http.Response('{"success":true,"ticket_id":"42"}', 201);
      }
      expect(action, 'support_close');
      expect(body['ticket_id'], 42);
      return http.Response('{"success":true}', 200);
    }));
    final id = await gateway.open(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'test-key',
      subject: 'Printer issue',
      message: 'It stopped printing.',
      email: 'owner@example.com',
    );
    await gateway.close(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'test-key',
      ticketId: id,
    );
    expect(actions, ['support_open', 'support_close']);
  });
}
