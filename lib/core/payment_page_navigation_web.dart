import 'dart:async';
import 'package:web/web.dart' as web;

/// Navigate the current browser tab instead of opening a delayed popup.
/// The checkout URL arrives only after an HTTP request, by which time browsers
/// commonly reject window.open() as no longer user-initiated. Same-tab
/// navigation is not popup-blocked, and Paystack's callback returns this exact
/// tab to NexaPOS afterwards.
Future<void> replaceWithPaymentPage(Uri uri) async {
  web.window.location.replace(uri.toString());
}
