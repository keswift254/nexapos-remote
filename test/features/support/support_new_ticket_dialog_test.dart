import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/features/support/support_screen.dart';

/// Opens the dialog the way the Support screen does.
Future<void> _open(WidgetTester tester, {String initialEmail = ''}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<SupportTicketDraft>(
                context: context,
                builder: (_) =>
                    SupportNewTicketDialog(initialEmail: initialEmail),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _fill(WidgetTester tester, {String? email}) async {
  await tester.enterText(_field('Subject'), 'Printer problem');
  await tester.enterText(_field('Describe the issue'), 'It will not print.');
  if (email != null) {
    await tester.enterText(_field('Email address (required)'), email);
  }
}

Future<void> _send(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Send ticket'));
  await tester.tap(find.text('Send ticket'));
  await tester.pumpAndSettle();
}

void main() {
  group('supportEmailProblem', () {
    test('accepts an ordinary address, with surrounding spaces', () {
      expect(supportEmailProblem('owner@example.com'), isNull);
      expect(supportEmailProblem('  owner@shop.co.ke '), isNull);
    });

    test('a blank address is a problem: replies are emailed there', () {
      expect(supportEmailProblem(''), contains('copy of every reply'));
      expect(supportEmailProblem('   '), contains('copy of every reply'));
    });

    test('something that is not an address is refused', () {
      for (final bad in [
        'owner',
        'owner@',
        '@example.com',
        'a@b',
        'a b@c.com',
      ]) {
        expect(
          supportEmailProblem(bad),
          'Enter a valid email address.',
          reason: bad,
        );
      }
    });
  });

  group('the new-ticket dialog', () {
    testWidgets('says the address is required and why', (tester) async {
      await _open(tester);
      expect(find.text('Email address (required)'), findsOneWidget);
      expect(find.text('We email you a copy of every reply.'), findsOneWidget);
      expect(find.textContaining('optional'), findsNothing);
    });

    testWidgets('will not send a ticket without an email address', (
      tester,
    ) async {
      await _open(tester);
      await _fill(tester);
      await _send(tester);
      expect(
        find.text('Open support ticket'),
        findsOneWidget,
        reason: 'the dialog stays open',
      );
      expect(
        find.text(
          'Enter your email address - we send a copy of every reply there.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('will not send a ticket with an invalid address', (
      tester,
    ) async {
      await _open(tester);
      await _fill(tester, email: 'not-an-email');
      await _send(tester);
      expect(find.text('Open support ticket'), findsOneWidget);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('hands back the draft with the address once it is valid', (
      tester,
    ) async {
      SupportTicketDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async =>
                    draft = await showDialog<SupportTicketDraft>(
                      context: context,
                      builder: (_) => const SupportNewTicketDialog(),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _fill(tester, email: ' owner@example.com ');
      await _send(tester);
      expect(find.text('Open support ticket'), findsNothing);
      expect(draft?.email, 'owner@example.com');
      expect(draft?.subject, 'Printer problem');
      expect(draft?.message, 'It will not print.');
    });

    testWidgets('starts with the address the shop gave before', (tester) async {
      await _open(tester, initialEmail: 'owner@example.com');
      final field = tester.widget<TextField>(
        _field('Email address (required)'),
      );
      expect(field.controller?.text, 'owner@example.com');
    });

    testWidgets('clears the complaint as soon as the address is edited', (
      tester,
    ) async {
      await _open(tester);
      await _fill(tester);
      await _send(tester);
      expect(find.textContaining('copy of every reply there'), findsOneWidget);
      await tester.enterText(_field('Email address (required)'), 'a');
      await tester.pumpAndSettle(); // the message fades out first
      expect(find.textContaining('copy of every reply there'), findsNothing);
    });
  });
}
