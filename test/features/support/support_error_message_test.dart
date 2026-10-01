import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/payments/paystack_gateway.dart'
    show PaystackException, PaystackOfflineException;
import 'package:nexapos_mobile/features/support/support_screen.dart';

/// A real customer report ("could not load support, check your connection")
/// turned out to be PaystackOfflineException, not PaystackException - a
/// distinction the Support screen used to collapse into one generic message
/// for every non-PaystackException failure. These pin the three real cases
/// apart so a future report says which one actually happened.
void main() {
  test('a real answer from the server is shown verbatim', () {
    expect(
      supportErrorMessage(const PaystackException('Subject must be between 3 and 160 characters.'), 'fallback'),
      'Subject must be between 3 and 160 characters.',
    );
  });

  test('a request that timed out says so, distinctly from no connection at all', () {
    expect(
      supportErrorMessage(const PaystackOfflineException(timedOut: true), 'fallback'),
      contains('taking too long'),
    );
  });

  test('a request that could not reach the server at all says so', () {
    final message = supportErrorMessage(const PaystackOfflineException(), 'fallback');
    expect(message, contains('Could not reach the support server'));
    expect(message, isNot(contains('taking too long')));
  });

  test('anything unexpected falls back to the caller\'s own message', () {
    expect(supportErrorMessage(StateError('boom'), 'Could not open the ticket.'), 'Could not open the ticket.');
  });
}
