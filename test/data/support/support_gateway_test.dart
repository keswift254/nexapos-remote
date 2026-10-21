import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart'
    show PaystackException;
import 'package:nexapos_mobile/data/support/support_gateway.dart';

void main() {
  test('read receipt posts the last visible support message with device auth', () async {
    final gateway = SupportGateway(MockClient((request) async {
      expect(request.url.queryParameters['action'], 'support_mark_read');
      expect(request.headers['Authorization'], 'Bearer shop-key');
      expect(jsonDecode(request.body), {'ticket_id': 7, 'through_message_id': 91});
      return http.Response('{"success":true,"marked":1}', 200);
    }));
    await gateway.markRead(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'shop-key',
      ticketId: 7,
      throughMessageId: 91,
    );
  });

  test('reads support IDs returned as strings by MySQL/PHP', () async {
    final gateway = SupportGateway(
      MockClient((request) async {
        switch (request.url.queryParameters['action']) {
          case 'support_list':
            return http.Response(
              jsonEncode({
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
              }),
              200,
            );
          case 'support_thread':
            expect(request.url.queryParameters['ticket_id'], '42');
            return http.Response(
              jsonEncode({
                'success': true,
                'ticket': {
                  'id': '42',
                  'subject': 'Printer issue',
                  'status': 'open',
                },
                'messages': [
                  {
                    'id': '99',
                    'sender': 'customer',
                    'body': 'Help',
                    'created_at': '2026-10-01 12:00:00',
                  },
                ],
              }),
              200,
            );
          default:
            fail('Unexpected action: ${request.url.queryParameters['action']}');
        }
      }),
    );

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
    final gateway = SupportGateway(
      MockClient((request) async {
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
      }),
    );
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
  test('includes selected photos when opening a new ticket', () async {
    final gateway = SupportGateway(
      MockClient((request) async {
        expect(request.url.queryParameters['action'], 'support_open');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['attachments'], [
          {
            'data': base64Encode([1, 2, 3]),
          },
        ]);
        return http.Response('{"success":true,"ticket_id":"73"}', 201);
      }),
    );
    final id = await gateway.open(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'shop-key',
      subject: 'Receipt photo',
      message: 'See attached',
      photos: [
        Uint8List.fromList([1, 2, 3]),
      ],
    );
    expect(id, 73);
  });
  test('shares pending list requests and isolates cached shops', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final gateway = SupportGateway(
      MockClient((request) {
        calls++;
        return pending.future;
      }),
    );
    final first = gateway.list(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'shop-a',
    );
    final second = gateway.list(
      baseUrl: 'https://example.com/index.php',
      apiKey: 'shop-a',
    );
    pending.complete(
      http.Response(
        '{"success":true,"tickets":[{"id":1,"subject":"Help","status":"pending","last_support_message_id":"7"}]}',
        200,
      ),
    );
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(
      gateway
          .cachedList('https://example.com/index.php', 'shop-a')!
          .single
          .replyToken,
      '1:7',
    );
    expect(
      gateway.cachedList('https://example.com/index.php', 'shop-b'),
      isNull,
    );
  });

  test(
    'sends photo bytes with a message and authenticates photo reads',
    () async {
      final gateway = SupportGateway(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer shop-key');
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['attachments'][0]['data'], base64Encode([1, 2, 3]));
            return http.Response('{"success":true}', 200);
          }
          expect(request.url.queryParameters['action'], 'support_attachment');
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      await gateway.reply(
        baseUrl: 'https://example.com/index.php',
        apiKey: 'shop-key',
        ticketId: 1,
        message: '',
        photos: [
          Uint8List.fromList([1, 2, 3]),
        ],
      );
      expect(
        await gateway.photo(
          baseUrl: 'https://example.com/index.php',
          apiKey: 'shop-key',
          id: 9,
        ),
        [1, 2, 3],
      );
    },
  );

  group('replies and reactions', () {
    const baseUrl = 'https://example.com/index.php';

    test('a reply carries the id of the message it quotes - and nothing when it quotes none', () async {
      final bodies = <Map<String, dynamic>>[];
      final gateway = SupportGateway(
        MockClient((request) async {
          expect(request.url.queryParameters['action'], 'support_reply');
          expect(request.headers['Authorization'], 'Bearer shop-key');
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"success":true,"message_id":12}', 200);
        }),
      );
      await gateway.reply(
        baseUrl: baseUrl,
        apiKey: 'shop-key',
        ticketId: 7,
        message: 'Quoting',
        replyToId: 3,
      );
      await gateway.reply(
        baseUrl: baseUrl,
        apiKey: 'shop-key',
        ticketId: 7,
        message: 'Plain',
      );
      expect(bodies[0], {
        'ticket_id': 7,
        'message': 'Quoting',
        'reply_to_id': 3,
      });
      expect(bodies[1], {
        'ticket_id': 7,
        'message': 'Plain',
      }, reason: 'an old server never sees a field it does not know');
    });

    test('a reaction is sent to support_react, and taking it off sends an empty emoji', () async {
      final bodies = <Map<String, dynamic>>[];
      final gateway = SupportGateway(
        MockClient((request) async {
          expect(request.url.queryParameters['action'], 'support_react');
          expect(request.headers['Authorization'], 'Bearer shop-key');
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"success":true}', 200);
        }),
      );
      await gateway.react(
        baseUrl: baseUrl,
        apiKey: 'shop-key',
        ticketId: 7,
        messageId: 99,
        emoji: '\u{1F44D}',
      );
      await gateway.react(
        baseUrl: baseUrl,
        apiKey: 'shop-key',
        ticketId: 7,
        messageId: 99,
        emoji: null,
      );
      expect(bodies[0], {
        'ticket_id': 7,
        'message_id': 99,
        'emoji': '\u{1F44D}',
      });
      expect(bodies[1], {'ticket_id': 7, 'message_id': 99, 'emoji': ''});
    });

    test('a refused reaction says why', () async {
      final gateway = SupportGateway(
        MockClient(
          (request) async => http.Response(
            '{"success":false,"message":"That reaction is not available."}',
            422,
          ),
        ),
      );
      await expectLater(
        gateway.react(
          baseUrl: baseUrl,
          apiKey: 'k',
          ticketId: 7,
          messageId: 1,
          emoji: 'x',
        ),
        throwsA(
          isA<PaystackException>().having(
            (e) => e.message,
            'message',
            'That reaction is not available.',
          ),
        ),
      );
    });

    test(
      'a thread brings the quote and the reactions of each message',
      () async {
        final gateway = SupportGateway(
          MockClient((request) async {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'success': true,
                  'ticket': {'id': 7, 'subject': 'Printer', 'status': 'open'},
                  'messages': [
                    {
                      'id': 1,
                      'sender': 'support',
                      'body': 'Restart it?',
                      'created_at': '2026-10-06 12:00:00',
                      'reply_to': null,
                      'reactions': [
                        {'sender': 'customer', 'emoji': '\u{1F44D}'},
                      ],
                    },
                    {
                      'id': '2',
                      'sender': 'customer',
                      'body': 'Done',
                      'created_at': '2026-10-06 12:01:00',
                      'reply_to': {
                        'id': '1',
                        'sender': 'support',
                        'snippet': 'Restart it?',
                      },
                      'reactions': [
                        {'sender': 'support', 'emoji': '\u2764\uFE0F'},
                        {'sender': 'customer', 'emoji': '\u{1F602}'},
                      ],
                    },
                    // What a server from before replies and reactions sends.
                    {
                      'id': 3,
                      'sender': 'support',
                      'body': 'Great',
                      'created_at': '2026-10-06 12:02:00',
                    },
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        final thread = await gateway.thread(
          baseUrl: baseUrl,
          apiKey: 'k',
          ticketId: 7,
        );
        final [first, second, third] = thread.messages;
        expect(first.replyTo, isNull);
        expect(first.myReaction?.emoji, '\u{1F44D}');
        expect(second.replyTo?.id, 1);
        expect(second.replyTo?.sender, 'support');
        expect(second.replyTo?.snippet, 'Restart it?');
        expect(second.reactions.map((r) => r.sender), ['support', 'customer']);
        expect(second.myReaction?.emoji, '\u{1F602}');
        expect(third.replyTo, isNull);
        expect(third.reactions, isEmpty);
        expect(third.myReaction, isNull);
      },
    );

    test('changing the shop\'s own reaction leaves support\'s alone', () {
      const message = SupportMessage(
        id: 1,
        sender: 'support',
        body: 'Hi',
        createdAt: '',
        reactions: [
          SupportReaction(sender: 'support', emoji: '\u2764\uFE0F'),
          SupportReaction(sender: 'customer', emoji: '\u{1F44D}'),
        ],
      );
      final changed = message.withMyReaction('\u{1F602}');
      expect(changed.reactions.map((r) => '${r.sender}:${r.emoji}'), [
        'support:\u2764\uFE0F',
        'customer:\u{1F602}',
      ]);
      final removed = message.withMyReaction(null);
      expect(removed.reactions.map((r) => r.sender), ['support']);
      expect(removed.id, 1);
      expect(removed.body, 'Hi');
    });
  });
}
