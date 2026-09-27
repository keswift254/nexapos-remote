import 'dart:js_interop';

@JS('nexaPOSUpdate')
external JSPromise<JSAny?> _update();

Future<void> refreshWebApplication() async {
  await _update().toDart;
}
