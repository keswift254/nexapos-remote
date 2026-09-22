# NexaPOS 1.0.40

- Browser POS keeps iPhone Home Screen shortcuts in Safari storage, registers and activates its offline worker immediately, requests persistent storage, and retries every precache file independently for reliable offline restart.
- Shop changes sync from the cloud about every 15 seconds, with an immediate sync after completed cash or online checkout; licensing, updates, and backups remain on the two-minute maintenance cadence.
- Native Android and Windows devices can exchange authenticated AES-256-GCM-encrypted shop changes directly over the local network when the internet is unavailable. The server-issued per-shop key is restricted to authenticated native clients, relayed revisions are source-validated and deduplicated, stock is recomputed after merges, and relayed work converges to the cloud later.

- NexaPOS now installs as a full desktop app on Windows 7, 8 and 8.1 (64-bit), with its own installer, desktop icon and Start Menu entry, the same as on Windows 10 and 11. Choose "Windows 7 / 8" in the Windows download box on the NexaPOS website. Windows 7 needs Service Pack 1.
- Computers on Windows 7 and 8 keep updating themselves from that edition's own installer, so an update never installs something their Windows cannot run.
- The Windows 10/11 installer now says clearly when it is run on Windows 7 or 8 and points to the right download.
- Fingerprint/Windows Hello sign-in is not available in the Windows 7/8 edition (Windows does not provide it there); passwords work as usual.
- The browser POS can reopen after one successful online visit even when the device is offline (after the first visit it keeps its own copy of the app; joined devices still need an online check at least once a day).
- Joining a shop is faster and clearer: a slow server now says so instead of showing "Offline", and the shop download no longer restarts from scratch on every retry.
- The web version's loading screen now shows a percentage inside the spinner, based on how much of the app has actually downloaded.
- A device that fails to join a shop (for example with an expired or already-used invite code) no longer gets stuck on "waiting for the shop's data": it goes back to the join screen so a fresh code can be entered.
- A device that already joined a shop can tap "Reconnect" on the join screen and go straight back in, with no invite code. (A shop's own owner device still unlocks with its license key, and a device the shop disabled cannot reconnect.)
- Joining a shop that a device is not actually recognised as the owner of, or a device this shop already disabled, is now clearly labelled on the join screen, with a way to reset that device and join a different shop instead of reinstalling.
- The shop-download progress screen no longer resets to zero every few seconds while it is still catching up - it now climbs smoothly, matching the web version.
- A device that joined a shop can leave it with just its administrator password - no separate authenticator code to set up, and no backup step, since its data already exists on the shop it is leaving. (A shop's own founding device still requires the full authenticator check and a backup, since its data may be the only copy.)
- The cart now asks for confirmation before removing an item from a sale, so a stray tap can no longer drop it silently.

All sales, sale items, expenses, payments, products, stock movements, users, roles, and business settings remain included. Windows and Android builds are cumulative. The installed POS is not modified by publication.
