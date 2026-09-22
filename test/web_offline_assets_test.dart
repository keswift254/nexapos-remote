import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS installs in browser mode and keeps Safari storage', () {
    final manifest = jsonDecode(File('web/manifest-ios.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(manifest['display'], 'browser');

    final index = File('web/index.html').readAsStringSync();
    expect(index, contains("isIOS ? 'manifest-ios.json' : 'manifest.json'"));
    expect(index, contains('navigator.storage.persist()'));
  });

  test('offline worker starts immediately, waits for activation, and retries files', () {
    final index = File('web/index.html').readAsStringSync();
    final worker = File('web/nexapos_service_worker.js').readAsStringSync();

    expect(index, isNot(contains("addEventListener('flutter-first-frame', function () { setTimeout(register")));
    expect(index, contains("worker.state === 'activated'"));
    expect(worker, isNot(contains('cache.addAll(')));
    expect(worker, contains('attempt <= 3'));
    expect(worker, contains('await cache.put(request, response)'));
  });
}
