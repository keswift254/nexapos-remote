# NexaPOS 1.0.39

- Fixed a database upgrade problem that could lock a device out of the app with a "duplicate column name" error, most likely to happen on a slow first load of the web version.
- Signing in now pauses for a short time after 5 wrong passwords in a row (30 seconds, growing with each further mistake), so passwords can't be guessed endlessly at the till. The pause survives closing and reopening the app.
- On Android, the app's data is no longer copied into the Google account backup. Restoring it onto a new phone used to give two phones the same identity and confuse syncing - a replacement phone should join the shop again with an invite code instead.
- The Windows installer now says clearly that NexaPOS needs Windows 10 or newer, instead of installing on Windows 7/8 where it cannot start.
- The web version shows a loading screen while it downloads instead of a blank page.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Windows and Android builds are cumulative. The installed POS is not modified by publication.
