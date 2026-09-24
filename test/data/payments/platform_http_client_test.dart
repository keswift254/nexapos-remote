import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/payments/platform_http_client.dart';

void main() {
  group('parseHttpDate', () {
    test('reads the standard HTTP date form as UTC', () {
      final parsed = parseHttpDate('Thu, 24 Sep 2026 12:30:05 GMT');

      expect(parsed, DateTime.utc(2026, 9, 24, 12, 30, 5));
      expect(parsed!.isUtc, isTrue);
    });

    test('reads a single-digit day and every month name', () {
      expect(parseHttpDate('Sun, 1 Jan 2028 00:00:00 GMT'), DateTime.utc(2028, 1, 1));
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (var i = 0; i < months.length; i++) {
        expect(parseHttpDate('Mon, 10 ${months[i]} 2026 10:20:30 GMT'), DateTime.utc(2026, i + 1, 10, 10, 20, 30));
      }
    });

    test('a missing or malformed header is null, never an exception', () {
      expect(parseHttpDate(null), isNull);
      expect(parseHttpDate(''), isNull);
      expect(parseHttpDate('yesterday'), isNull);
      expect(parseHttpDate('Thu, 24 Foo 2026 12:30:05 GMT'), isNull, reason: 'unknown month');
      expect(parseHttpDate('2026-09-24T12:30:05Z'), isNull, reason: 'not the HTTP form');
      expect(parseHttpDate('Thu, 24 Sep 2026 12:30:05 PST'), isNull, reason: 'only GMT is what a server sends');
    });
  });

  group('platformRequest onServerTime', () {
    test('is told the server clock from the response', () async {
      DateTime? seen;
      final client = MockClient((request) async => http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'date': 'Thu, 24 Sep 2026 12:30:05 GMT'},
      ));

      await platformRequest(client, 'GET', 'health', 'https://example.com/index.php', onServerTime: (t) => seen = t);

      expect(seen, DateTime.utc(2026, 9, 24, 12, 30, 5));
    });

    test('is not called when there is no Date header', () async {
      var called = false;
      final client = MockClient((request) async => http.Response(jsonEncode({'success': true}), 200));

      await platformRequest(client, 'GET', 'health', 'https://example.com/index.php', onServerTime: (_) => called = true);

      expect(called, isFalse);
    });

    test('is still told when the server answers with an error status', () async {
      DateTime? seen;
      final client = MockClient((request) async => http.Response(
        jsonEncode({'success': false, 'message': 'no'}),
        500,
        headers: {'date': 'Thu, 24 Sep 2026 12:30:05 GMT'},
      ));

      await expectLater(
        platformRequest(client, 'GET', 'health', 'https://example.com/index.php', onServerTime: (t) => seen = t),
        throwsA(isA<PaystackException>()),
      );
      expect(seen, isNotNull, reason: 'an error response is still real time from the server');
    });
  });
}
