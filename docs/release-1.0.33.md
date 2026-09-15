# NexaPOS 1.0.33

- Faster first shop sync downloads a resumable snapshot of current records instead of replaying repeated historical edits.
- Initial sync shows record counts, download/application progress, and actionable errors.
- Interrupted downloads resume from saved pages. Records and the sync cursor are committed together; existing data is retained on failure.
- Background sync requests share an in-flight cycle instead of queuing duplicate downloads.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Snapshots preserve the existing conflict rules and fetch subsequent changes after the snapshot boundary. Existing devices keep the legacy incremental endpoint.

Deploy the platform snapshot migration and endpoints before publishing these clients. Windows and Android builds are cumulative. The installed POS is not modified by publication.
