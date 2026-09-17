# NexaPOS 1.0.33

> This version number was originally planned for a different release
> (resumable first-sync snapshots) that was written up but never actually
> advertised - production never advertised anything past 1.0.32, so
> nothing real was lost by repurposing it for what's actually below. The
> resumable-sync work itself already shipped as part of 1.0.32's sync
> improvements.

- A cash sale can no longer be completed while cash tendered is short of the total - "Complete Sale" stays disabled until the shortfall is covered.
- When cash is short, an "Send M-Pesa prompt for [amount]" button sends an STK push for exactly the remaining balance, so the sale can be completed once it's paid.
- "Business Settings" renamed to "General Settings" throughout the app.
- Windows updates now install only via the setup EXE - the legacy ZIP-based update path (kept for pre-installer clients) is retired.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Windows and Android builds are cumulative. The installed POS is not modified by publication.
