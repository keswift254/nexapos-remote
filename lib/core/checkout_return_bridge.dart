import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CheckoutReturnBridge {
  static const _channel = MethodChannel('com.nexapos/checkout_return');
  static final ValueNotifier<int> signal = ValueNotifier(0);

  static bool _isCheckoutReturn(Object? value) =>
      value is String &&
      Uri.tryParse(value)?.scheme == 'nexapos' &&
      Uri.tryParse(value)?.host == 'checkout-return';

  static Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'checkoutReturn' &&
          _isCheckoutReturn(call.arguments)) {
        signal.value++;
      }
    });
    try {
      final initial = await _channel.invokeMethod<String>(
        'initialCheckoutReturn',
      );
      if (_isCheckoutReturn(initial)) signal.value++;
    } on MissingPluginException {
      // Tests and unsupported platforms do not install this native channel.
    } on PlatformException {
      // The periodic payment verifier remains the fallback.
    }
  }
}
