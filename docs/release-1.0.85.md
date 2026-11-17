# NexaPOS 1.0.85

A third way to take M-Pesa at checkout, in the Android, Windows and web versions: **M-Pesa Till/Paybill**. The customer pays the shop's own till or paybill, so the money reaches the shop straight away - no gateway in between.

- **Pick the customer's payment.** Choose M-Pesa Till/Paybill in the cart. The payments the shop's phone passed on (Safaricom's "payment received" messages) are listed, newest first, and the one that equals the sale total is marked. Tap it - or type the M-Pesa code - and Complete Sale.
- **One payment, one sale.** Before the sale is saved, the shop's server checks the code: it must be a payment that really arrived, for the sale's amount, and not already used on another sale. A payment smaller than the sale is refused; a bigger one is asked about first and the cashier is told how much to give back in cash.
- **Swipe an old payment away.** Swipe a suggested payment from right to left and confirm "Archive": it is no longer suggested at checkout on any till. It stays in NexaPOS Lite's Settings > M-Pesa Till Phone (where it can be suggested again), and its code can still be typed.
- **Receipts show the M-Pesa code** as "Reference", on screen, in the PDF and on thermal printers.
- **F8** now goes round all three payment methods: Cash, M-Pesa Prompt, M-Pesa Till/Paybill.
- Needs the internet (the check happens on the shop's server). The shop phone is set up once by an administrator in NexaPOS Lite: Settings > M-Pesa Till Phone.

Sales, stock, refunds, reports and licences are otherwise unchanged; till sales are saved as the "M-Pesa (Manual)" sales the apps already know, so reports and refunds handle them as before.
