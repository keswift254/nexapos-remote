import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';

const _base = 'https://sync.example/index.php';

void main() {
  late int requests;
  late Completer<void> answer;
  late PlatformSyncGateway gateway;

  setUp(() {
    requests = 0;
    answer = Completer<void>();
    gateway = PlatformSyncGateway(MockClient((request) async {
      requests++;
      await answer.future;
      return http.Response(jsonEncode({'success': true, 'changes': [], 'next_cursor': 0}), 200);
    }));
  });

  tearDown(() {
    if (!answer.isCompleted) answer.complete();
  });

  test('without a hold, requests are sent and answered as ever', () async {
    answer.complete();

    final pulled = await gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0);
    await gateway.pushChanges(baseUrl: _base, apiKey: 'k', changes: [
      {'table_name': 't', 'row_id': 'r'},
    ]);

    expect(pulled.changes, isEmpty);
    expect(requests, 2);
  });

  test('a request that is waiting is abandoned at once when a hold begins', () async {
    final pending = gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0);
    final result = pending.then<Object?>((_) => 'answered', onError: (Object e) => e);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(requests, 1);

    gateway.holdRequests();

    expect(await result.timeout(const Duration(seconds: 1)), isA<SyncRequestAbandoned>());
  });

  test('while held, new requests are refused WITHOUT being sent', () async {
    gateway.holdRequests();

    await expectLater(gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0), throwsA(isA<SyncRequestAbandoned>()));
    await expectLater(
      gateway.pushChanges(baseUrl: _base, apiKey: 'k', changes: [
        {'table_name': 't', 'row_id': 'r'},
      ]),
      throwsA(isA<SyncRequestAbandoned>()),
    );

    expect(requests, 0, reason: 'nothing left the device');
  });

  test('releasing the hold lets requests through again', () async {
    answer.complete();
    gateway.holdRequests();
    gateway.releaseRequests();

    await gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0);

    expect(requests, 1);
  });

  test('holds are counted: two LAN changes at once keep requests held until both are done', () async {
    answer.complete();
    gateway.holdRequests();
    gateway.holdRequests();
    gateway.releaseRequests();

    await expectLater(gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0), throwsA(isA<SyncRequestAbandoned>()));

    gateway.releaseRequests();
    await gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0);
    expect(requests, 1);
  });

  test('releasing more often than holding never goes below zero', () async {
    answer.complete();
    gateway.releaseRequests();
    gateway.releaseRequests();
    gateway.holdRequests();

    await expectLater(gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0), throwsA(isA<SyncRequestAbandoned>()));
  });

  test('the late answer of an abandoned request is ignored - it cannot surface as an unhandled error', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final pending = gateway.pullChanges(baseUrl: _base, apiKey: 'k', since: 0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gateway.holdRequests();
      await expectLater(pending, throwsA(isA<SyncRequestAbandoned>()));
      answer.complete(); // the server finally answers - into the void
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }, (error, stack) => errors.add(error));

    expect(errors, isEmpty);
  });

  test('the request that is not routine (the first download) is not affected by a hold', () async {
    answer.complete();
    gateway.holdRequests();

    // startSnapshot answers with an invalid body here; what matters is that it WAS sent.
    await expectLater(gateway.startSnapshot(_base, 'k'), throwsA(isNot(isA<SyncRequestAbandoned>())));
    expect(requests, 1);
  });
}
