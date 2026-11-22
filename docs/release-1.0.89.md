# NexaPOS 1.0.89

**Cash short? The rest can now be paid to your M-Pesa till or paybill, not only by M-Pesa prompt.** When the cash received is less than the total, the cart asks "How does the customer pay the rest?" with two choices:

- **Prompt to their phone** (the M-Pesa prompt, as before, and still the first choice): type the customer's number and send the prompt for the rest.
- **Paid to till/paybill**: the customer pays the rest to your own till or paybill. The cart shows the payments of exactly that amount, as M-Pesa Till/Paybill checkout does: the one new payment of the rest completes the sale by itself; with two or more, tap the customer's one, then Complete Sale (or F9). A bigger payment is asked about, and the change to give back is worked out against the rest.

The sale is saved like a split prompt sale: one paid sale with the cash part and the M-Pesa part. The receipt shows "Cash received" and "Paid via M-Pesa" with the M-Pesa code, reports count each part as cash and M-Pesa, and a refund gives the cash share back in proportion, the same in the app and in NexaPOS Lite.

The sale never completes by itself while the cursor is still in the cash box, so a half-typed cash amount is never used.
