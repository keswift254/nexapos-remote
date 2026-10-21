# NexaPOS 1.0.72

This update fixes device management and improves how Safari picks up a new web release.

- The primary device is marked clearly and cannot be revoked from Devices in This Shop. The server enforces the same protection even if an outdated app sends a revoke request.
- Revoked devices no longer appear in the shop's device list. Their records remain safely stored for history and auditing.
- The second Settings menu is now **Business, Receipts & Themes**.
- On Safari and other browsers, a newly activated offline worker reloads an untouched page into the new build. If someone is already working, the app offers a reload button instead of interrupting them.
- The web Support send sound uses a preloaded audio element so Safari can play it from the Send tap.

If Safari was already open during deployment, reload the page once; the new update handling takes effect from that visit. The shop's saved data and licence are not cleared.
