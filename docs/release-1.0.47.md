# NexaPOS 1.0.47

- **License time can no longer be changed by changing the date.** The time left on your license is now counted by the app itself, so setting the device's date back (or forward) does not give or take away license time. Every time the device reaches the internet it re-checks itself against the real time.
- **Shops that sell offline keep working until the license really ends.** Extra devices joined to a shop now get the shop's license time from the main device over the shop's own network - no internet needed - and stop exactly when the shop's license ends, with a clear message. Renewals reach them the same way.
- **The activation screen now explains why.** If the app locks because a license expired, was revoked, or a joined device needs to reconnect to the internet, it says so (and that your data is safe) instead of looking like a fresh install.
- **New: Settings > License.** Shows whether the license is active, expired or revoked, a live countdown of the time left, and this device's ID.
- **New: Settings > Region and Time.** Choose your country and time zone. NexaPOS now checks in the background that the device's clock and time zone are right, and shows a warning on the dashboard if not. On Windows, "Fix the clock now" corrects the time and time zone in one step (Windows asks permission once) and turns on Windows' automatic time sync. On Android it opens the Date & time settings.
- **Setup asks for your shop's region** so the time zone can be checked from the start.
- **Windows installers now turn on automatic time sync**, so a till's clock stays right by itself.
- **Windows 7/8: the app reopens by itself after an update.**

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Android, Windows 10/11, and Windows 7/8 builds are cumulative. The installed POS is not modified by publication.
