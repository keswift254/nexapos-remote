import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/lan_pull_policy.dart';

void main() {
  late LanPullPolicy policy;
  var now = Duration.zero;

  setUp(() {
    policy = LanPullPolicy();
    now = Duration.zero;
  });

  bool should(String peer, Map<String, int>? announced, Map<String, int> mine) =>
      policy.shouldPull(peer: peer, announced: announced, mine: mine, now: now);

  void pulled(String peer, Map<String, int>? announced) =>
      policy.pulled(peer: peer, announced: announced, now: now);

  test('a peer never pulled before is pulled straight away, even with nothing new', () {
    expect(should('a', {'a': 5}, {'a': 5}), isTrue);
  });

  test('a peer that sends no summary (an older version of the app) is always pulled, as before', () {
    pulled('old', null);
    now += const Duration(seconds: 2);
    expect(should('old', null, {'x': 1}), isTrue);
    now += const Duration(seconds: 2);
    expect(should('old', null, {'x': 1}), isTrue);
  });

  test('right after a pull, an announcement with nothing new is not worth another', () {
    pulled('a', {'a': 5, 'b': 2});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 5, 'b': 2}, {'a': 5, 'b': 2}), isFalse);
  });

  test('a peer ahead of this device in any one source is pulled', () {
    pulled('a', {'a': 5});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 6}, {'a': 5}), isTrue);
  });

  test('a source this device has never heard of counts as ahead', () {
    pulled('a', {'a': 5});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 5, 'c': 1}, {'a': 5}), isTrue);
  });

  test('a peer that is behind, or level, is not pulled', () {
    pulled('a', {'a': 5});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 4}, {'a': 5}), isFalse);
    expect(should('a', {'a': 5}, {'a': 5}), isFalse);
    expect(should('a', <String, int>{}, {'a': 5}), isFalse);
  });

  test('the same summary that was already pulled against is not pulled again, even if it stays ahead', () {
    // A summary can run ahead of what can be exported (revisions kept only as
    // receipts). Pulling every 2 seconds forever for that would defeat the point.
    pulled('a', {'a': 9});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 9}, {'a': 5}), isFalse);
    now += const Duration(seconds: 2);
    expect(should('a', {'a': 9}, {'a': 5}), isFalse);
  });

  test('...but a summary that then changes and is ahead is pulled', () {
    pulled('a', {'a': 9});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 10}, {'a': 5}), isTrue);
  });

  test('every peer is pulled at least every 30 seconds whatever it says', () {
    pulled('a', {'a': 5});
    now += const Duration(seconds: 29);
    expect(should('a', {'a': 5}, {'a': 5}), isFalse);

    now += const Duration(seconds: 1);
    expect(should('a', {'a': 5}, {'a': 5}), isTrue);
  });

  test('the safety interval restarts after each pull', () {
    pulled('a', {'a': 5});
    now += const Duration(seconds: 31);
    expect(should('a', {'a': 5}, {'a': 5}), isTrue);
    pulled('a', {'a': 5});

    now += const Duration(seconds: 10);
    expect(should('a', {'a': 5}, {'a': 5}), isFalse);
  });

  test('a pull that failed is not recorded, so the next announcement tries again', () {
    // (No call to pulled(): the exchange did not go through.)
    now += const Duration(seconds: 2);
    expect(should('a', {'a': 6}, {'a': 5}), isTrue);
    now += const Duration(seconds: 2);
    expect(should('a', {'a': 6}, {'a': 5}), isTrue);
  });

  test('peers are judged independently', () {
    pulled('a', {'a': 5});
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 5}, {'a': 5}), isFalse);
    expect(should('b', {'b': 1}, {'b': 1}), isTrue, reason: 'b has never been pulled');
  });

  test('a custom safety interval is honoured', () {
    final quick = LanPullPolicy(safetyInterval: const Duration(seconds: 5));
    quick.pulled(peer: 'a', announced: {'a': 1}, now: Duration.zero);

    expect(
      quick.shouldPull(peer: 'a', announced: {'a': 1}, mine: {'a': 1}, now: const Duration(seconds: 4)),
      isFalse,
    );
    expect(
      quick.shouldPull(peer: 'a', announced: {'a': 1}, mine: {'a': 1}, now: const Duration(seconds: 5)),
      isTrue,
    );
  });

  test('the summary kept for a peer is a copy, not the caller\'s map', () {
    final summary = {'a': 9};
    pulled('a', summary);
    summary['a'] = 10; // the caller reuses its map
    now += const Duration(seconds: 2);

    expect(should('a', {'a': 9}, {'a': 5}), isFalse);
  });
}
