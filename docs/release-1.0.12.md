# NexaPOS 1.0.12 candidate

## Device safety

- Check for Updates, update notifications and the update screen are available to every signed-in role, including cashier and manager. Administrative settings remain restricted. Opening the screen checks availability; installation still requires the user's explicit download/install action.

- Leaving or switching an established shop requires the current active administrator's password and an authenticator code, followed by a saved encrypted recovery backup. Cancelling or failing the backup leaves data intact.
- Inviting devices, unregistering, importing and creating backups require administrator verification. The platform separately restricts invitation creation to the shop-owner device.
- The authenticator is enrolled per administrator on each device. Keep a secure copy of the setup key. This factor is not exported, synced, or enforced by the platform's device API; it protects these actions in the updated client. First enrollment requires the administrator password.
- A persisted membership-change journal pauses sync and blocks business-table writes until server membership is resolved. Joined shops download users and settings before uploading or allowing setup. The cart is cleared on a shop change.
- Existing platform restrictions still prevent self-service departure from a shop with other devices. Device revocation remains an owner operation.

## Inventory transfer

Inventory has an administrator-only **Import all data from another POS** action beside Excel import. It opens the migration, encrypted backup and restore window.

For the older browser NexaPOS, enter `http://localhost/pos/public/index.php?page=login`, inspect the source, and enter its local XAMPP PHP executable and MySQL database connection details. The source reader uses a read-only consistent transaction. Passwords go to the PHP process through stdin, not command-line arguments or saved configuration.

The adapter handles the original NexaPOS users, categories, products, sales, sale items, stock movements, expenses and M-Pesa/Paystack payment records. Reports are rebuilt from those records, not copied as screenshots. Historical staff are disabled; current administrator access is preserved. Source product images, gateway secrets and file-based receipt settings are not migrated. Unsupported populated tables stop the import.

Inspect the record-count preview before importing. A recovery backup of the current shop is required. Missing relationships, conflicting IDs/SKUs/sale numbers, unsupported currency precision and inconsistent stock balances stop the import. Repeating an unchanged import does not duplicate records.

Native NexaPOS backups include business rows and available product images, encrypted with AES-256-GCM and a password-derived key. Store the backup password separately. Device identity, activation, payment credentials and authenticator secrets are excluded. Existing configured settings are never silently overwritten. An empty shop's default settings can be replaced by the backup settings.

Limits: 256 MiB encrypted backup, 128 MiB source export, 32 MiB product images. Windows performs local XAMPP database migration; other platforms can use the encrypted backup flow. Restores from another shop retain the target device's identity and treat imported records as new local changes for sync.

## Release gates

1. Deploy the matching platform changes first: `client_status.shop_id`, owner-only invitations, and rejection of invitations to the current shop.
2. Verify migration against a copy of the customer's actual database schema and reconcile counts, sales totals, expenses and stock before migrating production. The URL identifies the site but cannot expose its full database on its own. The current adapter has synthetic-fixture coverage, not verification against this customer's inaccessible source files.
3. Run Flutter analysis, the complete test suite and platform integration tests. Verify the Windows candidate manually on a disposable shop, including authenticator enrollment, backup cancellation and restore.
4. Build Windows and Android from this same commit. Publish immutable versioned download filenames and verify their SHA-256 hashes before updating `set_latest_version`. Do not announce or publish 1.0.12 until these checks pass.
5. Keep the platform legacy sync limit at 1000 until older clients have upgraded to the client that sends batches of 200. Then lower it to 200.

iOS packaging, signing and device testing follow the verified Windows/Android release. No iOS build is included in this candidate.

## Owner's release preference

Build and commit releases in separate folders on G:. Upload the verified artifacts to the download website and publish the version metadata after verification. Never replace, launch an updater against, or close the owner's currently running Windows installation during development or publication. The owner installs manually through Check for Updates. A source commit alone does not publish a binary, and unchanged download hashes must not be relabeled as a newer version.
