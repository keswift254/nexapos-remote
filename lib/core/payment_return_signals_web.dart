import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Name shared with the site's payment-return.html (publish-site) - change both together.
const paymentReturnChannelName = 'nexapos-payment-return';

/// Tells a waiting checkout screen that the customer is probably back from the
/// payment page, so it can ask the server about the payment right away instead
/// of at its next timer tick. Only ever a cue to check - never proof of payment.
///
/// Three independent cues, because browsers disagree about which of them they
/// send (an iPhone Home Screen app, for one, shows the payment page over the
/// running app and may fire none of the page events when it closes):
///  * the payment return page announces itself on a BroadcastChannel, and is
///    answered so it knows a live NexaPOS tab is already waiting;
///  * the page becoming visible again, and
///  * the window regaining focus or being restored from the back/forward cache.
class PaymentReturnSignals {
  final void Function() _onReturn;
  web.BroadcastChannel? _channel;
  late final JSFunction _onVisibility = ((web.Event _) {
    if (web.document.visibilityState == 'visible') _onReturn();
  }).toJS;
  late final JSFunction _onFocus = ((web.Event _) => _onReturn()).toJS;
  late final JSFunction _onPageShow = ((web.Event _) => _onReturn()).toJS;

  PaymentReturnSignals(this._onReturn) {
    try {
      final channel = web.BroadcastChannel(paymentReturnChannelName);
      channel.onmessage = ((web.MessageEvent event) {
        final data = event.data;
        if (data.isA<JSString>() && (data as JSString).toDart == 'returned') {
          channel.postMessage('ack'.toJS);
          _onReturn();
        }
      }).toJS;
      _channel = channel;
    } catch (_) {
      // Very old browsers have no BroadcastChannel; the other cues still work.
    }
    web.document.addEventListener('visibilitychange', _onVisibility);
    web.window.addEventListener('focus', _onFocus);
    web.window.addEventListener('pageshow', _onPageShow);
  }

  void dispose() {
    _channel?.close();
    _channel = null;
    web.document.removeEventListener('visibilitychange', _onVisibility);
    web.window.removeEventListener('focus', _onFocus);
    web.window.removeEventListener('pageshow', _onPageShow);
  }
}
