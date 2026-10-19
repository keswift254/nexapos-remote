# NexaPOS 1.0.67

Follow-up to 1.0.66. Install it on every device; nothing about selling, stock, licences or payments changes.

- **Old Windows 7 PCs can join a shop, sync and update again.** On a Windows 7 PC whose certificate store has not been refreshed, joining a shop failed with "HandshakeException ... CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate" (and syncing and downloading updates would too). The app now carries the public Let's Encrypt root certificates that NexaPOS's servers use, in addition to the ones Windows provides.
- **The "still to be uploaded" note now clears for the records it could not clear before.** A record the server refused because it already held a different copy of that revision (or because its timestamp was off) used to stay in the list for good. The app now gives such a record a fresh revision and uploads it again, so the note goes away on its own. The data itself is not changed.

This release does not change the licence, payment or database format. Windows 7/8 keeps its separate installer.
