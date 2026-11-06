/// Native builds come back from the payment page through the nexapos:// link
/// (see CheckoutReturnBridge), so there is nothing extra to listen for here.
class PaymentReturnSignals {
  PaymentReturnSignals(void Function() onReturn);

  void dispose() {}
}
