# NexaPOS 1.0.34

- New "Connected Devices" screen under Settings: see every device that has joined the shop, whether it's online or offline (and for how long), and revoke one - a revoked device is wiped and returns to the activation screen.
- The cart now survives closing the app, a device restart, or an update install - nothing added to it is lost. A dashboard notification points back to it whenever a sale is left pending.
- Removed the optional customer name/phone fields from the cart. The M-Pesa prompt button no longer needs a phone number typed in - it goes straight to the same STK push as before.
- Reports now show Total Cash Received and Total Paid by M-Pesa alongside the existing totals.
- General Settings' thermal printer configuration now supports a USB-connected printer, not just a network one. If no printer is configured yet, printing a receipt says so clearly instead of failing silently.
- Inventory items can be given a barcode, and scanning one (or typing it into the search field and pressing Enter) adds that product straight to the cart.
- The dashboard checks for an available update as soon as it loads or is refreshed, instead of only every two minutes - a freshly published update now shows up right away.
- Joining a shop now shows live sync progress (message, progress bar, record count) instead of leaving the "Join" button showing a spinner for the whole first sync, and keeps retrying automatically until the sync genuinely finishes.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Windows and Android builds are cumulative. The installed POS is not modified by publication.
