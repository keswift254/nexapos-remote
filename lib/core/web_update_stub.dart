/// See web_update_web.dart. Only the browser build can update itself this way.
Future<String?> refreshWebApplication({
  void Function(double? fraction, String phrase)? onProgress,
}) async => 'Browser updates are only available on the web.';
