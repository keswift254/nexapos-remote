import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// flutter_secure_storage's real backends (Windows Credential Manager,
/// Keychain, etc.) only register via generated_plugin_registrant.dart,
/// which `flutter run` wires up but plain `flutter test`'s host binary
/// does not - any awaited read/write/delete against the real plugin
/// throws MissingPluginException under widget tests. Call this in
/// setUp (or once per test) to back the channel with a plain in-memory
/// map instead, matching the method names/argument shapes
/// MethodChannelFlutterSecureStorage actually sends.
void installFakeSecureStorage() {
  final values = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    final args = call.arguments as Map;
    switch (call.method) {
      case 'read':
        return values[args['key'] as String];
      case 'write':
        values[args['key'] as String] = args['value'] as String;
        return null;
      case 'delete':
        values.remove(args['key'] as String);
        return null;
      case 'containsKey':
        return values.containsKey(args['key'] as String);
      case 'readAll':
        return values;
      case 'deleteAll':
        values.clear();
        return null;
      default:
        return null;
    }
  });
}
