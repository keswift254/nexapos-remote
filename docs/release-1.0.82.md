# NexaPOS 1.0.82

Refunds: an administrator or a manager can now give money back for a sale, in the Android, Windows and web versions. Selling, stock, licences and the M-Pesa prompt are not affected.

- **Refund a sale.** Open the sale's receipt (from Reports) and tap Refund. Choose the whole sale or just some of each item, say why, and confirm with your own password. Only an administrator or a manager can do this; a cashier does not see the button.
- **Stock goes back, unless it cannot.** Each item you give back is put back in stock by default. Switch that off for goods that are damaged or cannot be sold again.
- **The money is paid back by you.** NexaPOS records the refund and tells you how much to hand back in cash or send back by M-Pesa. It does not send money itself.
- **Discounts are fair.** If the sale had a discount, the refund gives back only the discount's share of what is refunded, to the cent, so several refunds of one sale always add up to exactly what the customer paid.
- **A REFUND receipt** can be shown, printed on the thermal printer or shared as a PDF: it says what was refunded, why, and by whom.
- **Reports show refunds.** Reports have a Refunds figure and list, a refunded sale says Refunded or Part refunded, and Grand Total is paid sales minus refunds minus expenses. The day's printed report lists the refunds, and Sales Today on the dashboard is after refunds.
- **Older versions on other devices still add up correctly:** a refund is recorded as its own sale with negative amounts, so a device that has not been updated yet still shows the right totals (it just lists the refund as a negative sale).
