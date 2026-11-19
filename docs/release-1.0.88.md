# NexaPOS 1.0.88

**M-Pesa Till/Paybill at checkout shows only the payment that fits the sale.** Choose M-Pesa Till/Paybill in the cart and only the payments of exactly the sale total are shown, not every payment that came in.

- **One new payment of the sale total:** the sale completes by itself and the receipt opens. "New" means it reached the shop in the last 10 minutes.
- **Two or more payments of the sale total:** the cart says how many arrived. Tap the one this customer made, then Complete Sale. The others stay suggested for the next sales until a sale uses them or you archive them.
- **One payment of the sale total that is older than 10 minutes:** it is only suggested, because it may be an earlier customer's. Tap it if it is this customer's.
- **No payment of the sale total yet:** the cart waits and completes the sale as soon as one arrives.
- **The customer paid a different amount:** tap "Customer paid a different amount? Show the other payments" to see them. A bigger payment is asked about, as before.

The sale does not complete by itself when you have picked or typed a code yourself, and a payment the shop refused once is not tried again by itself.

**Settings > M-Pesa Till Phone shows each phone's sender check.** "On" means the phone's Shortcut passes on who each SMS came from, so the shop refuses a message that a person typed and sent from their own number. "Off" means the Shortcut still needs the new "sender" field (step 10 of the phone set-up page).
