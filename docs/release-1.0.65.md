# NexaPOS 1.0.65

Data-safety update. Install it on every device; nothing about selling, stock, licences or payments changes.

- **A lost security key can no longer destroy your saved data.** On Windows the app keeps a second copy of the file that holds its secrets and puts it back if the first one is damaged (for example after a power cut). If the app ever cannot unlock its saved data it now stops and explains what happened instead of silently starting an empty shop; nothing is deleted, and you can choose to rebuild from the cloud.
- **One bad record can no longer keep the rest of your shop off the cloud.** If the server refuses a single record, the app sets only that one aside, keeps it on the device, and carries on uploading everything else.
- **The dashboard now tells you** when data has been waiting to upload for more than a day, or when the server refused some records, instead of failing silently.
- **Automatic backups are kept longer.** Besides the newest seven, one backup per day is kept for 14 days.

This release does not change the licence, payment or database format. Windows 7/8 keeps its separate installer.
