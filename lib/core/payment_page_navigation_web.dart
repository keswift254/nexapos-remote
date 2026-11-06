import 'dart:async';
import 'package:web/web.dart' as web;

/// Navigate the current browser tab instead of opening a delayed popup.
/// The checkout URL arrives only after an HTTP request, by which time browsers
/// commonly reject window.open() as no longer user-initiated. Same-tab
/// navigation is not popup-blocked, and Paystack's callback returns this exact
/// tab to NexaPOS afterwards.
///
/// [replace] drops this page from the history (the licence purchase does, since
/// there is nothing to come back to). A sale keeps it, so the browser's Back
/// button from the payment page lands in NexaPOS again instead of a dead end.
Future<void> replaceWithPaymentPage(Uri uri, {bool replace = true}) async {
  if (replace) {
    web.window.location.replace(uri.toString());
  } else {
    web.window.location.assign(uri.toString());
  }
}
