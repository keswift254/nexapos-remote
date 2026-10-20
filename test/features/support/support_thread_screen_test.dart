import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/payments/paystack_gateway.dart'
    show PaystackException;
import 'package:nexapos_mobile/data/repositories/business_settings_repository_impl.dart';
import 'package:nexapos_mobile/data/support/support_gateway.dart';
import 'package:nexapos_mobile/domain/entities/business_settings.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/repositories/business_settings_repository.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/features/support/support_screen.dart';
import 'package:nexapos_mobile/features/support/support_sound.dart';

final _tinyPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Credentials implements PaystackCredentialsService {
  @override
  Future<PaystackCredentials> load() async => const PaystackCredentials(
    baseUrl: 'https://example.test/index.php',
    apiKey: 'key',
    currency: 'KES',
    defaultEmail: 'customer@example.com',
  );
  @override
  Future<void> save(PaystackCredentials value) async {}
  @override
  Future<String> loadDeviceLabel() async => '';
  @override
  Future<void> saveDeviceLabel(String label) async {}
  @override
  Future<void> clearRegistration() async {}
}

class _Settings implements BusinessSettingsRepository {
  @override
  Future<BusinessSettings> get() async => const BusinessSettings(
    businessName: 'PENT CYBER',
    currency: 'KES',
    paperWidthMm: 58,
  );
  @override
  Future<void> update(BusinessSettings settings) async {}
}

class _Sound implements SupportSound {
  int plays = 0;
  @override
  Future<void> playSent() async => plays++;
}

/// A server that keeps the conversation in memory.
class _Server extends SupportGateway {
  _Server(this.messages);
  List<SupportMessage> messages;
  int threadCalls = 0;
  final replies = <({String message, int? replyToId, int photos})>[];
  final reactions = <({int messageId, String? emoji})>[];
  Completer<void>? holdReply;
  bool failReply = false;
  bool failReact = false;
  bool failThread = false;

  @override
  SupportThread? cachedThread(String baseUrl, String apiKey, int id) => null;

  @override
  Future<SupportThread> thread({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
  }) async {
    threadCalls++;
    if (failThread) throw const PaystackException('No connection.');
    return SupportThread(
      ticket: const SupportTicket(
        id: 7,
        subject: 'Printer offline',
        status: 'open',
        createdAt: '',
        updatedAt: '',
      ),
      messages: List.of(messages),
    );
  }

  @override
  Future<void> reply({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
    required String message,
    List<Uint8List> photos = const [],
    int? replyToId,
  }) async {
    replies.add((
      message: message,
      replyToId: replyToId,
      photos: photos.length,
    ));
    if (holdReply != null) await holdReply!.future;
    if (failReply) throw const PaystackException('No connection.');
    final quoted = replyToId == null
        ? null
        : messages.firstWhere((m) => m.id == replyToId);
    messages.add(
      SupportMessage(
        id: messages.length + 1,
        sender: 'customer',
        body: message,
        createdAt: '2026-10-06 12:10:00',
        replyTo: quoted == null
            ? null
            : SupportQuote(
                id: quoted.id,
                sender: quoted.sender,
                snippet: quoted.body,
              ),
      ),
    );
  }

  @override
  Future<void> react({
    required String baseUrl,
    required String apiKey,
    required int ticketId,
    required int messageId,
    required String? emoji,
  }) async {
    reactions.add((messageId: messageId, emoji: emoji));
    if (failReact) throw const PaystackException('Could not save.');
  }

  @override
  Future<Uint8List> photo({
    required String baseUrl,
    required String apiKey,
    required int id,
  }) async => _tinyPng;
}

SupportMessage _support(int id, String body) => SupportMessage(
  id: id,
  sender: 'support',
  body: body,
  createdAt: '2026-10-06 12:00:00',
);

void main() {
  late _Server server;
  late _Sound sound;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paystackCredentialsServiceProvider.overrideWithValue(_Credentials()),
          businessSettingsRepositoryProvider.overrideWithValue(_Settings()),
          supportGatewayProvider.overrideWithValue(server),
          supportSoundProvider.overrideWithValue(sound),
        ],
        child: const MaterialApp(
          home: SupportThreadScreen(
            ticket: SupportTicket(
              id: 7,
              subject: 'Printer offline',
              status: 'open',
              createdAt: '',
              updatedAt: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
  }

  Future<void> doubleTap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    server = _Server([_support(1, 'Hello from support')]);
    sound = _Sound();
  });

  testWidgets('sending: "Sending…" at once, then "Delivered" with the sound', (
    tester,
  ) async {
    server.holdReply = Completer<void>();
    await open(tester);
    await type(tester, 'The till froze');
    await send(tester);

    expect(find.text('Sending…'), findsOneWidget);
    expect(
      find.text('The till froze'),
      findsOneWidget,
      reason: 'the message is on screen immediately',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
      reason: 'and the box is clear',
    );
    expect(sound.plays, 0, reason: 'no sound until the server has it');
    expect(find.text('Delivered'), findsNothing);

    server.holdReply!.complete();
    await tester.pumpAndSettle();
    expect(sound.plays, 1);
    expect(find.text('Sending…'), findsNothing);
    expect(
      find.text('The till froze'),
      findsOneWidget,
      reason: 'now as the real message, not a duplicate',
    );
    expect(find.text('Delivered'), findsOneWidget);
    expect(server.replies.single.message, 'The till froze');
    expect(server.replies.single.replyToId, isNull);
  });

  testWidgets(
    'a message that could not be sent says so, plays no sound, and a tap tries again',
    (tester) async {
      server.failReply = true;
      await open(tester);
      await type(tester, 'Please help');
      await send(tester);
      await tester.pumpAndSettle();

      expect(find.text('Not delivered. Tap to try again'), findsOneWidget);
      expect(
        find.text('No connection.'),
        findsOneWidget,
        reason: 'the reason, in a snackbar',
      );
      expect(sound.plays, 0);
      expect(find.text('Delivered'), findsNothing);

      server.failReply = false;
      await tester.tap(find.text('Please help'));
      await tester.pumpAndSettle();
      expect(server.replies.length, 2, reason: 'sent again');
      expect(server.replies.last.message, 'Please help');
      expect(find.text('Not delivered. Tap to try again'), findsNothing);
      expect(find.text('Delivered'), findsOneWidget);
      expect(sound.plays, 1);
    },
  );

  testWidgets('nothing is sent for an empty box', (tester) async {
    await open(tester);
    await send(tester);
    await tester.pumpAndSettle();
    expect(server.replies, isEmpty);
    expect(sound.plays, 0);
  });

  testWidgets(
    'Reply: shows who and what you are answering, sends it as a reply, then clears',
    (tester) async {
      await open(tester);
      await doubleTap(tester, find.text('Hello from support'));
      await tester.tap(find.byKey(const ValueKey('menu-reply')));
      await tester.pumpAndSettle();

      expect(find.text('Replying to NexaPOS Support'), findsOneWidget);
      expect(
        find.text('Hello from support'),
        findsNWidgets(2),
        reason: 'the message and the preview of it',
      );

      await type(tester, 'Thanks, one question');
      await send(tester);
      await tester.pumpAndSettle();

      expect(server.replies.single.replyToId, 1);
      expect(
        find.text('Replying to NexaPOS Support'),
        findsNothing,
        reason: 'the preview is gone after sending',
      );
      expect(
        find.text('Hello from support'),
        findsNWidgets(2),
        reason: 'the message and the quote inside the new reply',
      );
    },
  );

  testWidgets('the cross cancels a reply', (tester) async {
    await open(tester);
    await doubleTap(tester, find.text('Hello from support'));
    await tester.tap(find.byKey(const ValueKey('menu-reply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancel reply'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to NexaPOS Support'), findsNothing);

    await type(tester, 'Never mind');
    await send(tester);
    await tester.pumpAndSettle();
    expect(server.replies.single.replyToId, isNull);
  });

  testWidgets('a reply that fails keeps its quote when tried again', (
    tester,
  ) async {
    server.failReply = true;
    await open(tester);
    await doubleTap(tester, find.text('Hello from support'));
    await tester.tap(find.byKey(const ValueKey('menu-reply')));
    await tester.pumpAndSettle();
    await type(tester, 'Quoting you');
    await send(tester);
    await tester.pumpAndSettle();
    expect(server.replies.single.replyToId, 1);

    server.failReply = false;
    await tester.tap(find.text('Quoting you'));
    await tester.pumpAndSettle();
    expect(
      server.replies.last.replyToId,
      1,
      reason: 'the retry still quotes the same message',
    );
  });

  testWidgets('Copy puts the message on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(tester);
    await doubleTap(tester, find.text('Hello from support'));
    await tester.tap(find.byKey(const ValueKey('menu-copy')));
    await tester.pumpAndSettle();
    expect(copied, 'Hello from support');
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets(
    'a reaction shows at once, is saved, and tapping it again takes it off',
    (tester) async {
      await open(tester);
      await doubleTap(tester, find.text('Hello from support'));
      await tester.tap(find.byKey(const ValueKey('react-\u{1F44D}')));
      await tester.pumpAndSettle();
      expect(find.text('\u{1F44D}'), findsOneWidget);
      expect(server.reactions.single, (messageId: 1, emoji: '\u{1F44D}'));

      await tester.tap(find.text('\u{1F44D}'));
      await tester.pumpAndSettle();
      expect(find.text('\u{1F44D}'), findsNothing);
      expect(server.reactions.last, (messageId: 1, emoji: null));
    },
  );

  testWidgets('a reaction the server refuses is taken back, with a message', (
    tester,
  ) async {
    server.failReact = true;
    await open(tester);
    await doubleTap(tester, find.text('Hello from support'));
    await tester.tap(find.byKey(const ValueKey('react-\u{1F602}')));
    await tester.pumpAndSettle();
    expect(find.text('\u{1F602}'), findsNothing);
    expect(find.text('Could not save.'), findsOneWidget);
  });

  testWidgets('support\'s reaction shows too', (tester) async {
    server.messages = [
      SupportMessage(
        id: 1,
        sender: 'customer',
        body: 'My question',
        createdAt: '2026-10-06 12:00:00',
        reactions: const [SupportReaction(sender: 'support', emoji: '❤️')],
      ),
    ];
    await open(tester);
    expect(find.text('❤️'), findsOneWidget);
  });

  testWidgets(
    'every 20 seconds new messages arrive on their own, and a failed refresh leaves the conversation alone',
    (tester) async {
      await open(tester);
      final before = server.threadCalls;
      server.messages.add(_support(2, 'A reply that arrived later'));
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(server.threadCalls, greaterThan(before));
      expect(find.text('A reply that arrived later'), findsOneWidget);

      server.failThread = true;
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(
        find.text('A reply that arrived later'),
        findsOneWidget,
        reason: 'still there',
      );
      expect(find.text('Could not load this ticket.'), findsNothing);
      expect(find.text('No connection.'), findsNothing);
    },
  );

  testWidgets('the conversation opens on its newest message', (tester) async {
    server.messages = [
      for (var i = 1; i <= 60; i++) _support(i, 'Message number $i'),
    ];
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Message number 60'), findsOneWidget);
    expect(find.text('Message number 1'), findsNothing);
  });
}
