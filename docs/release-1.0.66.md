# NexaPOS 1.0.66

Small follow-up to 1.0.65. Install it on every device; nothing about selling, stock, licences or payments changes.

- **Records the server did not accept are tried again.** In 1.0.65 a record the shop server refused was set aside and never looked at again, so the dashboard warning about it stayed forever. Now every set-aside record is offered to the server again every few hours; as soon as the server takes it, it leaves the list and the warning goes away on its own.
- **A calmer dashboard note.** A few records waiting to be accepted now show as a quiet "still to be uploaded" note that says they are safe and are being retried. The red warning is kept for when your data is genuinely not reaching the cloud.

This release does not change the licence, payment or database format. Windows 7/8 keeps its separate installer.
