# NexaPOS 1.0.45

- Fixed the dashboard sometimes still showing the old shop's sales and records right after leaving or switching shops, until the app was fully closed and reopened.
- Fixed "Reset this device and join a different shop" refusing to work on a device that still held its old (disabled) shop's data - the normal state for a device that was actually used, not just a fresh install. Choosing "Reset identity + erase data" now works in that case; "Reset identity only" still asks you to erase the data first or reconnect instead.
- Lowered the minimum account password length from 8 to 6 characters, including during first-time setup after activating a license.
- Revoking a device (or a license simply expiring) now locks that device back to the activation screen within about 15 seconds instead of up to 2 minutes.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Android, Windows 10/11, and Windows 7/8 builds are cumulative. The installed POS is not modified by publication.
