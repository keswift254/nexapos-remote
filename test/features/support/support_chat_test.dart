import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nexapos_mobile/data/support/support_gateway.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/features/support/support_chat.dart';
import 'package:nexapos_mobile/features/support/support_sound.dart';

final _tinyPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _PhotoGateway extends SupportGateway {
  @override
  Future<Uint8List> photo({
    required String baseUrl,
    required String apiKey,
    required int id,
  }) async => _tinyPng;
}

const _credentials = PaystackCredentials(
  baseUrl: 'https://example.test/index.php',
  apiKey: 'key',
  currency: 'KES',
  defaultEmail: 'customer@example.com',
);

/// Midday UTC, so the local date is the same in every time zone that matters.
SupportMessage _message(
  int id,
  String sender,
  String body, {
  String createdAt = '2026-10-06 12:00:00',
  SupportQuote? replyTo,
  List<SupportReaction> reactions = const [],
  List<int> attachments = const [],
}) => SupportMessage(
  id: id,
  sender: sender,
  body: body,
  createdAt: createdAt,
  replyTo: replyTo,
  reactions: reactions,
  attachments: attachments,
);

final _today = DateTime(2026, 10, 7, 9);

String _timeOf(String createdAt) =>
    DateFormat.jm().format(parseSupportTime(createdAt)!);

void main() {
  group('the send sound', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    Future<Uint8List> shipped() async {
      final data = await rootBundle.load(sentSoundAsset);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    }

    test(
      'the file that ships with the app is a real, short, audible WAV',
      () async {
        final wav = await shipped();
        final data = ByteData.sublistView(wav);
        String tag(int at) => String.fromCharCodes(wav.sublist(at, at + 4));
        expect(tag(0), 'RIFF');
        expect(tag(8), 'WAVE');
        expect(tag(12), 'fmt ');
        expect(
          data.getUint16(20, Endian.little),
          1,
          reason: 'uncompressed PCM, which every player takes',
        );
        final channels = data.getUint16(22, Endian.little);
        expect(channels, anyOf(1, 2));
        expect(data.getUint16(34, Endian.little), 16, reason: '16-bit');
        final sampleRate = data.getUint32(24, Endian.little);
        expect(sampleRate, inInclusiveRange(16000, 48000));
        // The data chunk follows the fmt chunk straight away (the Android player also copes with other layouts).
        expect(tag(36), 'data');
        final dataLength = data.getUint32(40, Endian.little);
        expect(wav.length, 44 + dataLength);
        final seconds = dataLength / 2 / channels / sampleRate;
        expect(
          seconds,
          inInclusiveRange(0.3, 3.0),
          reason: 'a short chirp, not a song',
        );

        var peak = 0;
        for (var i = 44; i + 1 < wav.length; i += 2) {
          final sample = data.getInt16(i, Endian.little).abs();
          if (sample > peak) peak = sample;
        }
        expect(peak, greaterThan(4000), reason: 'audible, not silence');
        expect(peak, lessThan(32000), reason: 'not clipping');
        expect(
          data.getInt16(wav.length - 2, Endian.little).abs(),
          lessThan(800),
          reason: 'ends near zero: no click',
        );
      },
    );

    test('playing it hands the shipped bytes to the device player - once loaded, reused', () async {
      final played = <Uint8List>[];
      var loads = 0;
      final sound = DeviceSupportSound(
        play: (wav) async => played.add(wav),
        load: (asset) async {
          loads++;
          expect(asset, sentSoundAsset);
          final bytes = await shipped();
          return ByteData.sublistView(bytes);
        },
      );
      await sound.playSent();
      await sound.playSent();
      expect(played, hasLength(2));
      expect(played.first, await shipped());
      expect(loads, 1, reason: 'the file is read once');
    });

    test('a player that fails never throws into sending', () async {
      final sound = DeviceSupportSound(
        play: (wav) async => throw StateError('no speaker'),
        load: (asset) async => ByteData.sublistView(await shipped()),
      );
      await sound.playSent();
    });

    test('a missing sound file never throws into sending either', () async {
      var played = false;
      final sound = DeviceSupportSound(
        play: (wav) async => played = true,
        load: (asset) async => throw FlutterError('Unable to load asset'),
      );
      await sound.playSent();
      expect(played, isFalse);
    });
  });

  group('times', () {
    test('the server\'s UTC timestamps become local time', () {
      final utc = DateTime.utc(2026, 10, 6, 12, 0, 21);
      expect(parseSupportTime('2026-10-06 12:00:21'), utc.toLocal());
      expect(parseSupportTime('2026-10-06T12:00:21Z'), utc.toLocal());
      expect(parseSupportTime(''), isNull);
      expect(parseSupportTime('not a time'), isNull);
    });

    test('day headings', () {
      final now = DateTime(2026, 10, 7, 9);
      expect(supportDayLabel(DateTime(2026, 10, 7, 0, 5), now), 'Today');
      expect(supportDayLabel(DateTime(2026, 10, 6, 23, 59), now), 'Yesterday');
      expect(supportDayLabel(DateTime(2026, 10, 5, 12), now), 'Mon 5 Oct');
    });
  });

  group('the conversation', () {
    Future<void> show(
      WidgetTester tester,
      List<SupportMessage> messages, {
      SupportPendingMessage? pending,
      void Function(SupportMessage)? onReply,
      void Function(SupportMessage, String?)? onReact,
      void Function(SupportMessage)? onCopy,
      VoidCallback? onRetry,
      Widget header = const Text('Ticket header'),
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportGatewayProvider.overrideWithValue(_PhotoGateway()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SupportConversation(
                header: header,
                messages: messages,
                credentials: _credentials,
                shopName: 'PENT CYBER',
                pending: pending,
                onRetryPending: onRetry,
                onReply: onReply ?? (_) {},
                onReact: onReact ?? (_, _) {},
                onCopy: onCopy ?? (_) {},
                now: () => _today,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Color? bubbleColor(WidgetTester tester, String text) {
      final box = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    Future<void> doubleTap(WidgetTester tester, Finder finder) async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the shop\'s messages are rgb(0, 120, 254) with white text, support\'s are grey',
      (tester) async {
        await show(tester, [
          _message(1, 'customer', 'My till is stuck'),
          _message(2, 'support', 'We are looking'),
        ]);
        expect(
          bubbleColor(tester, 'My till is stuck'),
          const Color.fromRGBO(0, 120, 254, 1),
        );
        expect(supportBlue, const Color(0xFF0078FE));
        expect(
          tester.widget<Text>(find.text('My till is stuck')).style?.color,
          Colors.white,
        );
        expect(
          bubbleColor(tester, 'We are looking'),
          Theme.of(tester.element(find.text('We are looking')))
              .colorScheme
              .surfaceContainerHighest,
        );
        expect(find.text('PENT CYBER'), findsOneWidget);
        expect(find.text('NexaPOS Support'), findsOneWidget);
      },
    );

    testWidgets(
      '"Delivered" sits under the last message, only when the shop sent it',
      (tester) async {
        await show(tester, [
          _message(1, 'support', 'Hello'),
          _message(2, 'customer', 'Hi'),
        ]);
        expect(find.text('Delivered'), findsOneWidget);
        final deliveredY = tester.getTopLeft(find.text('Delivered')).dy;
        expect(
          deliveredY,
          greaterThan(tester.getBottomLeft(find.text('Hi')).dy),
        );

        await show(tester, [
          _message(1, 'customer', 'Hi'),
          _message(2, 'support', 'Hello'),
        ]);
        expect(
          find.text('Delivered'),
          findsNothing,
          reason: 'support spoke last',
        );

        await show(tester, [
          _message(1, 'customer', 'One'),
          _message(2, 'customer', 'Two'),
        ]);
        expect(
          find.text('Delivered'),
          findsOneWidget,
          reason: 'only under the last one',
        );
      },
    );

    testWidgets('a message on its way says "Sending…", not "Delivered"', (
      tester,
    ) async {
      await show(tester, [
        _message(1, 'customer', 'Earlier'),
      ], pending: const SupportPendingMessage(body: 'New one', photoCount: 0));
      expect(find.text('Sending…'), findsOneWidget);
      expect(find.text('New one'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('a message that failed says so, and a tap tries again', (
      tester,
    ) async {
      var retried = 0;
      await show(
        tester,
        [_message(1, 'support', 'Hello')],
        pending: const SupportPendingMessage(
          body: 'Lost',
          photoCount: 2,
          failed: true,
        ),
        onRetry: () => retried++,
      );
      expect(find.text('Not delivered. Tap to try again'), findsOneWidget);
      expect(find.text('2 photos'), findsOneWidget);
      await tester.tap(find.text('Lost'));
      expect(retried, 1);
    });

    testWidgets(
      'the time of each message is hidden until the conversation is dragged sideways',
      (tester) async {
        await show(tester, [
          _message(1, 'support', 'Hello', createdAt: '2026-10-06 12:00:00'),
          _message(2, 'customer', 'Hi', createdAt: '2026-10-06 12:07:00'),
        ]);
        final label = _timeOf('2026-10-06 12:07:00');
        Opacity timeOpacity() => tester.widget<Opacity>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Opacity))
              .first,
        );
        expect(timeOpacity().opacity, 0, reason: 'not showing at rest');
        final restX = tester.getTopLeft(find.text('Hi')).dx;

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Hello')),
        );
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
        expect(
          timeOpacity().opacity,
          inExclusiveRange(0.1, 0.9),
          reason: 'a short drag shows them part-way',
        );
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        expect(
          timeOpacity().opacity,
          1,
          reason: 'a longer drag shows the times in full',
        );
        expect(
          tester.getTopLeft(find.text('Hi')).dx,
          closeTo(restX - 64, 1),
          reason: 'the conversation slid left',
        );
        expect(
          tester.getTopLeft(find.text(label)).dx,
          lessThan(
            tester.view.physicalSize.width / tester.view.devicePixelRatio,
          ),
          reason: 'the time is on screen',
        );

        await gesture.up();
        await tester.pumpAndSettle();
        expect(timeOpacity().opacity, 0, reason: 'springs back when let go');
        expect(tester.getTopLeft(find.text('Hi')).dx, closeTo(restX, 0.5));
      },
    );

    testWidgets('a half-way drag shows the times half-way', (tester) async {
      await show(tester, [
        _message(1, 'customer', 'Hi', createdAt: '2026-10-06 12:07:00'),
      ]);
      final label = _timeOf('2026-10-06 12:07:00');
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hi')),
      );
      double opacity() => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Opacity))
                .first,
          )
          .opacity;
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      final first = opacity();
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump();
      expect(first, inExclusiveRange(0, 1));
      expect(opacity(), greaterThan(first), reason: 'it follows the finger');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'dragging the other way, or only a little, shows nothing extra',
      (tester) async {
        await show(tester, [
          _message(1, 'customer', 'Hi', createdAt: '2026-10-06 12:07:00'),
        ]);
        final label = _timeOf('2026-10-06 12:07:00');
        final restX = tester.getTopLeft(find.text('Hi')).dx;
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Hi')),
        );
        await gesture.moveBy(const Offset(80, 0));
        await tester.pump();
        expect(
          tester.getTopLeft(find.text('Hi')).dx,
          restX,
          reason: 'rightwards does not move it',
        );
        expect(
          tester
              .widget<Opacity>(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity,
          0,
        );
        await gesture.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('each day gets a heading', (tester) async {
      await show(tester, [
        _message(1, 'support', 'Old', createdAt: '2026-10-05 12:00:00'),
        _message(
          2,
          'customer',
          'Yesterday one',
          createdAt: '2026-10-06 12:00:00',
        ),
        _message(
          3,
          'customer',
          'Yesterday two',
          createdAt: '2026-10-06 12:30:00',
        ),
        _message(4, 'support', 'Fresh', createdAt: '2026-10-07 08:00:00'),
      ]);
      expect(find.text('Mon 5 Oct'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('double-tap opens the menu: six emoji, Reply and Copy', (
      tester,
    ) async {
      await show(tester, [_message(1, 'support', 'Hello there')]);
      await doubleTap(tester, find.text('Hello there'));
      for (final emoji in supportReactionChoices) {
        expect(find.byKey(ValueKey('react-$emoji')), findsOneWidget);
      }
      expect(supportReactionChoices, hasLength(6));
      expect(find.byKey(const ValueKey('menu-reply')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-copy')), findsOneWidget);
    });

    testWidgets('long-press opens it too', (tester) async {
      await show(tester, [_message(1, 'support', 'Hello there')]);
      await tester.longPress(find.text('Hello there'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-reply')), findsOneWidget);
    });

    testWidgets('a single tap does not open it', (tester) async {
      await show(tester, [_message(1, 'support', 'Hello there')]);
      await tester.tap(find.text('Hello there'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-reply')), findsNothing);
    });

    testWidgets('choosing an emoji reacts to that message', (tester) async {
      final reacted = <(int, String?)>[];
      await show(tester, [
        _message(1, 'support', 'Hello'),
        _message(2, 'support', 'Second'),
      ], onReact: (m, e) => reacted.add((m.id, e)));
      await doubleTap(tester, find.text('Second'));
      await tester.tap(find.byKey(const ValueKey('react-\u{1F44D}')));
      await tester.pumpAndSettle();
      expect(reacted, [(2, '\u{1F44D}')]);
      expect(
        find.byKey(const ValueKey('menu-reply')),
        findsNothing,
        reason: 'the menu closed',
      );
    });

    testWidgets('choosing the emoji already chosen takes the reaction off', (
      tester,
    ) async {
      final reacted = <String?>[];
      await show(tester, [
        _message(
          1,
          'support',
          'Hello',
          reactions: const [SupportReaction(sender: 'customer', emoji: '❤️')],
        ),
      ], onReact: (m, e) => reacted.add(e));
      await doubleTap(tester, find.text('Hello'));
      await tester.tap(find.byKey(const ValueKey('react-❤️')));
      await tester.pumpAndSettle();
      expect(reacted, [null]);
    });

    testWidgets('Reply and Copy report which message', (tester) async {
      SupportMessage? replied;
      SupportMessage? copied;
      await show(
        tester,
        [_message(1, 'support', 'Hello there')],
        onReply: (m) => replied = m,
        onCopy: (m) => copied = m,
      );
      await doubleTap(tester, find.text('Hello there'));
      await tester.tap(find.byKey(const ValueKey('menu-reply')));
      await tester.pumpAndSettle();
      expect(replied?.id, 1);
      expect(copied, isNull);

      await doubleTap(tester, find.text('Hello there'));
      await tester.tap(find.byKey(const ValueKey('menu-copy')));
      await tester.pumpAndSettle();
      expect(copied?.id, 1);
    });

    testWidgets(
      'a photo-only message cannot be copied, but can be replied to',
      (tester) async {
        SupportMessage? copied;
        await show(tester, [
          _message(1, 'support', '', attachments: const [5]),
        ], onCopy: (m) => copied = m);
        await tester.pump();
        await doubleTap(tester, find.byType(Image).first);
        expect(
          find.byKey(const ValueKey('menu-reply')),
          findsOneWidget,
          reason: 'double-tap on the photo opens the menu too',
        );
        await tester.tap(find.byKey(const ValueKey('menu-copy')));
        await tester.pumpAndSettle();
        expect(copied, isNull);
      },
    );

    testWidgets('tapping outside the menu closes it and does nothing', (
      tester,
    ) async {
      var calls = 0;
      await show(
        tester,
        [_message(1, 'support', 'Hello there')],
        onReact: (_, _) => calls++,
        onReply: (_) => calls++,
        onCopy: (_) => calls++,
      );
      await doubleTap(tester, find.text('Hello there'));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-reply')), findsNothing);
      expect(calls, 0);
    });

    testWidgets(
      'reactions show under the message; tapping your own removes it, the other side\'s copies it',
      (tester) async {
        final reacted = <String?>[];
        await show(tester, [
          _message(
            1,
            'support',
            'Hello',
            reactions: const [
              SupportReaction(sender: 'support', emoji: '\u{1F602}'),
              SupportReaction(sender: 'customer', emoji: '❤️'),
            ],
          ),
        ], onReact: (m, e) => reacted.add(e));
        expect(find.text('\u{1F602}'), findsOneWidget);
        expect(find.text('❤️'), findsOneWidget);
        await tester.tap(find.text('\u{1F602}'));
        await tester.tap(find.text('❤️'));
        expect(reacted, ['\u{1F602}', null]);
      },
    );

    testWidgets('a reply shows the message it quotes', (tester) async {
      await show(tester, [
        _message(1, 'support', 'Did you restart it?'),
        _message(
          2,
          'customer',
          'Yes, twice',
          replyTo: const SupportQuote(
            id: 1,
            sender: 'support',
            snippet: 'Did you restart it?',
          ),
        ),
        _message(
          3,
          'support',
          'Thanks',
          replyTo: const SupportQuote(id: 2, sender: 'customer', snippet: ''),
        ),
      ]);
      expect(
        find.text('Did you restart it?'),
        findsNWidgets(2),
        reason: 'the message and its quote',
      );
      expect(
        find.text('Photo'),
        findsOneWidget,
        reason: 'a quote with no text reads "Photo"',
      );
      expect(find.text('NexaPOS Support'), findsNWidgets(3));
    });

    testWidgets('tapping a quote scrolls to the message it quotes', (
      tester,
    ) async {
      final messages = [
        _message(1, 'support', 'The very first message'),
        for (var i = 2; i <= 40; i++)
          _message(
            i,
            i.isEven ? 'customer' : 'support',
            'Filler message number $i',
          ),
        _message(
          41,
          'customer',
          'Answering the first one',
          replyTo: const SupportQuote(
            id: 1,
            sender: 'support',
            snippet: 'The very first message',
          ),
        ),
      ];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportGatewayProvider.overrideWithValue(_PhotoGateway()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SupportConversation(
                controller: controller,
                header: const SizedBox.shrink(),
                messages: messages,
                credentials: _credentials,
                shopName: 'PENT CYBER',
                onReply: (_) {},
                onReact: (_, _) {},
                onCopy: (_) {},
                now: () => _today,
              ),
            ),
          ),
        ),
      );
      // The list learns its true length as the last messages get built: keep going to the end.
      for (
        var i = 0;
        i < 20 && find.text('Answering the first one').evaluate().isEmpty;
        i++
      ) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final bottom = controller.offset;
      expect(bottom, greaterThan(500));
      // The quote is the one with the first message's text inside the last bubble.
      await tester.tap(
        find.descendant(
          of: find
              .ancestor(
                of: find.text('Answering the first one'),
                matching: find.byType(AnimatedContainer),
              )
              .first,
          matching: find.text('The very first message'),
        ),
      );
      // A tap inside a message that can be double-tapped waits out the double-tap time first.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        lessThan(bottom - 400),
        reason: 'scrolled back up to the quoted message',
      );
      // The quoted message is outlined for a moment; let that finish.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
