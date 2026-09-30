# NexaPOS 1.0.57

LAN, payment-flow, update-permission and support release.

- Fixed native LAN sync after joining or switching shops by replacing stale pre-join LAN credentials immediately.
- Windows setup now permits NexaPOS's authenticated/encrypted LAN traffic through Windows Firewall.
- Activation checkout opens automatically; web uses the same tab to avoid popup blockers.
- Payment status continues checking automatically and successful checkout returns to the initiating native app or web POS.
- Android update flow guides the one-time "Allow from this source" approval and continues automatically after returning from Settings.
- Added a Support icon beside Settings with shop-scoped support tickets, ticket history, threaded messages and replies.
