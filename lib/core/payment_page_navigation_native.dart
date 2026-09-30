import 'dart:async';

/// Web-only same-tab navigation hook. Native checkout uses url_launcher and
/// never calls this implementation.
Future<void> replaceWithPaymentPage(Uri uri) async {}
