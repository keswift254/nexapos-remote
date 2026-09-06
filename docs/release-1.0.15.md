# NexaPOS 1.0.15 (build 16)

Fixes migration of older POS sales with missing item cost prices. Keeps sales,
payments and inventory, and warns when historical profit lacks cost information.

The PHP schema allows sale_items.cost_price to be NULL. Only this optional
historical cost maps to zero; other required amounts remain strict. The preview
reports how many costs were missing and explains the effect on profit reports.
Current product prices are never used to invent historical costs.

The opt-in test NEXAPOS_LEGACY_CHECK=1 reads the local source and imports into an
in-memory database, reconciling row counts and sales totals and checking repeat
imports. It never modifies the source or the installed application's database.

Validation passed against the local nexapos database: 8 products, 464 sales,
614 sale items, 68 expenses and 124 payment records. 189 sale items had missing
costs. All 10 import tests passed and import-code static analysis was clean.

Publish matching Windows ZIP, setup EXE and Android APK with checksums before
advertising the release. Keep older versioned downloads for existing updaters.
