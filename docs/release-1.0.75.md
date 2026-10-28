# NexaPOS 1.0.75

Google Drive backup works again on Windows, and support asks for an email address on every ticket. Nothing about selling, stock, licences or payments changes.

- **Google Drive backup on Windows.** Installed copies of NexaPOS built since 1.0.53 could not talk to Google Drive: an account that had been connected earlier still showed "Connected", but the list of backups failed with "client_secret is missing" and uploads never worked. This build includes what Google needs, so listing, uploading and restoring backups work again.
- **Clear Drive messages.** If Google no longer accepts the saved sign-in (it expired, or you removed NexaPOS in your Google account), the screen says so and offers a **Reconnect** button instead of a raw error. A list that cannot load now shows its error within seconds instead of spinning for half a minute, with a **Try again** button.
- **An email address is required on every support ticket** (this was prepared for 1.0.74, which was never published). A copy of every reply from support is emailed to it, and the field starts with the address from your last ticket. Earlier versions follow the same rule through the support server.
- **Support chat on the website** for visitors of nexapos.cc, with quick self-help answers first and photo attachments.

If Drive backup still says "Reconnect", tap it once and sign in again; your existing Drive backups are kept. This release does not change the licence, payment or database format. Windows 7/8 keeps its separate installer.
