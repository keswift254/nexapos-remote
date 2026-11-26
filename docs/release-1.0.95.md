# NexaPOS 1.0.95

**An Android phone can pass the till's M-Pesa messages on, like the iPhone Shortcut - from NexaPOS itself.** The owner asked for Android phones to send the payment messages to the shop too. On Android this needs no shortcut: NexaPOS receives the text messages and passes the payment ones on in the background, even when it is closed.

- **Set up:** on an Android phone that is a till of the shop, Settings > M-Pesa Till Phone > **Use this phone** (the administrator's password, then Turn on). On a phone that does nothing else, **This phone only passes on M-Pesa messages** on NexaPOS's first screen - no shop to join - and paste the till phone key from the PC (Settings > M-Pesa Till Phone > Set up a phone, Copy key; the set-up page the PC's code opens shows these steps too).
- **What leaves the phone:** only messages from a named sender (MPESA, a bank - or a bank's short code) that mention Ksh, KES or Confirmed. A message from a person's phone number or an e-mail address never leaves the phone - the same rule the shop's server applies - so nobody can forward a copied M-Pesa text from their own phone. The shop then keeps only real payments received, as with the iPhone.
- **No internet:** each message waits on the phone and goes as soon as it is online (tried again for over a day, also after a restart).
- **The screen** (M-Pesa messages from this phone) shows whether it is on, the last message passed on and what the shop said about it, and how many are waiting. Android 13 and later ask once to "Allow restricted settings" for an app that did not come from a store; the screen shows how.

Android only; Windows, iPhone and the web POS behave as before.
