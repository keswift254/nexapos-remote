import 'dart:js_interop';

@JS('nexaPOSUpdate')
external JSPromise<JSAny?> _update(JSFunction onProgress);

/// Downloads the newest version of the web app and restarts the page on it (see
/// `window.nexaPOSUpdate` in web/index.html). Returns null once the page is on its way
/// to restarting, or a sentence saying why the update could not be done. [onProgress]
/// gets the fraction downloaded (null while not known yet) and a short phrase.
Future<String?> refreshWebApplication({
  void Function(double? fraction, String phrase)? onProgress,
}) async {
  final callback = ((JSNumber fraction, JSString phrase) {
    final value = fraction.toDartDouble;
    onProgress?.call(value.isNaN || value < 0 ? null : value, phrase.toDart);
  }).toJS;
  final outcome = await _update(callback).toDart;
  return outcome.isA<JSString>() ? (outcome as JSString).toDart : null;
}
