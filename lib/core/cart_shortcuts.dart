import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ShortcutActivator, SingleActivator;

/// The keys that act on the cart while it is open, and the words that tell the cashier about them (the hover hints).
///
/// They are bound once, for the whole app (see app.dart), so they work wherever the keyboard focus happens to be
/// (typing in the search box, the phone number, or nowhere at all). The cart screen registers what each key does
/// while it is on screen; with no cart open the keys do nothing at all.
///
///  * F8                 switch between Cash and M-Pesa Prompt
///  * F9 or Ctrl+Enter   complete the sale (cash) / send the M-Pesa prompt (M-Pesa Prompt)
class CartShortcuts {
  CartShortcuts._();

  static const switchPaymentHint = 'F8';
  static const completeHint = 'F9 or Ctrl+Enter';

  static Object? _owner;
  static VoidCallback? _switchPayment;
  static VoidCallback? _complete;

  /// The cart screen on show takes the keys. [owner] is that screen (so another cart opened on top, or an old one
  /// disposed late, never takes the keys away from the wrong screen).
  static void register({
    required Object owner,
    required VoidCallback switchPayment,
    required VoidCallback complete,
  }) {
    _owner = owner;
    _switchPayment = switchPayment;
    _complete = complete;
  }

  static void unregister(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _switchPayment = null;
    _complete = null;
  }

  /// Whether a cart is on show and holds the keys.
  static bool get isActive => _owner != null;

  static void switchPayment() => _switchPayment?.call();

  static void complete() => _complete?.call();

  /// The bindings for the app-wide shortcut table.
  static Map<ShortcutActivator, VoidCallback> get bindings => {
    const SingleActivator(LogicalKeyboardKey.f8): switchPayment,
    const SingleActivator(LogicalKeyboardKey.f9): complete,
    const SingleActivator(LogicalKeyboardKey.enter, control: true): complete,
    const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true): complete,
  };
}
