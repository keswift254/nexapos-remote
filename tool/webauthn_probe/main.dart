// A tiny browser page for trying the web quick-sign-in gateway on its own (not shipped with the app):
//   dart compile js tool/webauthn_probe/main.dart -o build/probe/main.dart.js
// then serve tool/webauthn_probe/index.html next to the compiled script over http://localhost or https.
// Each button runs one gateway call and writes its result into #log.
import 'dart:js_interop';

import 'package:nexapos_mobile/domain/services/device_authentication_gateway_web.dart';
import 'package:web/web.dart' as web;

void main() {
  final gateway = WebDeviceAuthenticationGateway();
  final log = web.document.getElementById('log')!;

  void write(String line) => log.textContent = '${log.textContent ?? ''}$line\n';

  void on(String id, Future<String> Function() action) {
    web.document.getElementById(id)!.addEventListener(
      'click',
      (web.Event _) {
        action().then((result) => write('$id: $result')).catchError((Object error) {
          write('$id: ERROR $error');
          return null;
        });
      }.toJS,
    );
  }

  on('supported', () async => '${await gateway.isSupported()}');
  on('why', () => gateway.whyUnsupported());
  on('canTry', () async => '${await gateway.canTryAnyway()}');
  on('enrolled', () async => '${await gateway.isEnrolled()}');
  on('enroll', () async => '${await gateway.enroll()}');
  on('authenticate', () async => '${await gateway.authenticate()}');
  on('forget', () async {
    await gateway.forget();
    return 'forgotten';
  });
}
