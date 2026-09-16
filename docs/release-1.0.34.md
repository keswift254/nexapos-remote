# NexaPOS 1.0.34

- Cash sale checkout can record how much cash was tendered and shows the change due (or amount still owed) live on the cart screen. Assistive only - it never blocks completing a sale.
- Receipts (on-screen, PDF, and thermal print) now show a plain payment method label (e.g. "M-Pesa") instead of the raw gateway name, plus the cash received/change lines when recorded.
- IntaSend removed from the checkout payment-method picker - Paystack (M-Pesa Prompt) covers online payment. Existing sales recorded as IntaSend, and any still in flight, continue to work.
- Initial shop sync (a freshly joined device downloading its first snapshot) retries every 5 seconds instead of every 2 minutes when there's known, immediate work left, and the join screen shows the real current status/error instead of a generic placeholder.
- Fixed a blank page on iOS Safari opening the browser-based POS: a missing viewport tag and an unresumable database-storage failure could both leave the page silently blank.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Windows and Android builds are cumulative. The installed POS is not modified by publication.
