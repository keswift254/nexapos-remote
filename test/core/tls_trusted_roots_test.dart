import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/tls_trusted_roots_io.dart';

// A throwaway CA that exists only for these tests (fixtures/tls); its private key
// was discarded after it signed the localhost certificate.
final _fixtures = Directory('test/core/fixtures/tls');

String _fingerprint(String pem) {
  final body = pem
      .split('\n')
      .where((line) => !line.startsWith('-----'))
      .join();
  return sha256
      .convert(base64.decode(body))
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

void main() {
  test('the built-in roots are exactly the published ISRG Root X1 and X2', () {
    expect(
      _fingerprint(isrgRootX1Pem),
      '96:BC:EC:06:26:49:76:F3:74:60:77:9A:CF:28:C5:A7:CF:E8:A3:C0:AA:E1:1A:8F:FC:EE:05:C0:BD:DF:08:C6',
    );
    expect(
      _fingerprint(isrgRootX2Pem),
      '69:72:9B:8E:15:A8:6E:FC:17:7A:57:AF:B7:17:1D:FC:64:AD:D2:8C:2F:CA:8C:F1:50:7E:34:45:3C:CB:14:70',
    );
    expect(nexaposExtraRootPems, hasLength(2));
  });

  test('garbage never throws and adds nothing', () {
    expect(installExtraTrustedRoots(pems: ['not a certificate', '']), 0);
  });

  test('a certificate from an unknown root is refused until its root is added', () async {
    final root = File('${_fixtures.path}/test_root.pem').readAsStringSync();
    final context = SecurityContext()
      ..useCertificateChainBytes(File('${_fixtures.path}/test_leaf.pem').readAsBytesSync())
      ..usePrivateKeyBytes(File('${_fixtures.path}/test_leaf.key').readAsBytesSync());
    final server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.write('hello');
      request.response.close();
    });

    Future<String> fetch() async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('https://localhost:${server.port}/'));
        final response = await request.close();
        return await utf8.decodeStream(response);
      } finally {
        client.close(force: true);
      }
    }

    // Exactly the Windows 7 symptom: the machine has never heard of this root.
    await expectLater(fetch(), throwsA(isA<HandshakeException>()));

    expect(installExtraTrustedRoots(pems: [root]), 1);

    // The same plain HttpClient() (what package:http uses) now succeeds.
    expect(await fetch(), 'hello');
  });

  test('the built-in roots install without complaint', () {
    expect(installExtraTrustedRoots(), 2);
  });
}
