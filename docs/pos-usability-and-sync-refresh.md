# POS usability and dashboard refresh — September 27, 2026

Included in release 1.0.52+53.

- Web activation and software-update screens offer Download & Install. The browser updates its service worker, downloads application assets with HTTP cache bypass, then reloads. Ordinary offline caching resumes afterward. Shop databases (IndexedDB/OPFS), credentials and preferences are not deleted. Failed downloads show a retry message and do not replace cached files.
- Dashboard database notifications carry increasing revision numbers. Previously every notification was `void`/null: Riverpod suppressed equal successive values, so later LAN changes did not recompute the dashboard.
- Windows opens maximized using the monitor's work area, retaining normal window controls.
- Global keyboard controls: Esc closes the top dialog or goes back (respecting unsaved-change guards; no action at the root), F2 new sale, F4 cart, Alt+Home dashboard, Alt+Left back, F1 help. Existing Tab/Shift+Tab focus traversal, Enter/Space button activation and menu navigation remain available. Route authorization still applies to shortcut navigation.
- Dashboard summary cards stack below 560 logical pixels (adjusted for text scaling) and stay side-by-side on larger screens.

## Verification

- 54 targeted Flutter tests passed: dashboard, repeated LAN application through the actual dashboard provider, migration/archive integrity, catalog import, shop safety and update screens.
- Full dashboard layout passed at widths 320, 800 and 1920 pixels; financial-privacy regression also passed.
- Two service-worker tests passed: network cache bypass and preserving existing cached files when download fails.
- A read-only integration test connected to the real local PHP POS and imported into a temporary in-memory database: 2 users, 6 categories, 8 products, 464 sales, 614 sale items, 68 expenses, 340 stock movements and 124 payment records. Sales totals, foreign keys and repeated-import idempotency passed. The source database was not modified.
- Flutter analysis found no errors. One newly introduced brace-style lint was fixed; the unrelated existing relative-import info in `tool/receipt_branding_preview.dart` remains.
- Full release suite: 795 passed, 3 skipped, 4 failures in the existing real-socket LAN timing tests. An unrestricted rerun transferred data but still missed timing targets (3.7s and 5.4s versus <3s) and timed out on one test. The LAN transport and those timing tests are unchanged in this release; this does not establish a clean end-to-end LAN performance gate. Client-device acceptance remains required.

## Deployment and device acceptance

The 1.0.52 web build includes the normal sizes and offline-cache stamping passes. Existing clients must first receive this web build to see the new button. Native release downloads are published separately from the generator's update announcement. Test the browser update once online and then offline, and verify maximized startup and keyboard checkout on a Windows device. Automated tests do not replace a two-device hardware check of the refreshed dashboard. The real shop app on the development PC was not launched or installed over during verification.

The import verification covers the supported legacy NexaPOS adapter and catalog/archive paths, not arbitrary third-party POS database schemas.
