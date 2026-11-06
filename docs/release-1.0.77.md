# NexaPOS 1.0.77

Online M-Pesa payments on the web version (the browser and the iPhone Home Screen copy) now open, come back and confirm by themselves. Nothing about stock, reports or licences changes, and the Windows and Android apps are not affected.

- **The payment page opens by itself.** The web version used to open Paystack in a new tab after contacting the server, and Safari blocks tabs opened that way, so the cashier had to tap "Open checkout page again" every time. It now opens in the same window.
- **It brings you back to NexaPOS.** After paying, the customer's browser returns to NexaPOS instead of stopping on Paystack's own page.
- **The result shows up as soon as you are back.** NexaPOS checks the payment the moment the page returns. An earlier check that got stuck while the page was in the background can no longer hold it up, and checks run every few seconds while you wait.
- **A payment confirmed while you were away is not missed.** If the app locked or reloaded on the way back, the sale is still finalised, and the dashboard says "Payment received for ..." with a link to the receipt. Payments that are still unpaid are re-checked every 10 seconds, wherever you are in the app.
