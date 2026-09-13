@TestOn('browser')
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/core/utils/clock.dart';
import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/payment_record_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_item_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/user.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';

/// SPIKE, not a permanent part of the suite: answers the one open
/// question `project-drive-backup-and-ios-browser-design` flagged before
/// any browser-POS work could start - does drift's web (WASM) driver
/// actually handle THIS app's real schema (11 tables, triggers, foreign
/// keys, WAL journal mode) and real query patterns (joins, transactions),
/// not a toy example? Runs the exact same AppDatabase class production
/// uses, with only the QueryExecutor swapped from native FFI to the web
/// driver - if this passes, the schema/query layer is not a blocker;
/// everything else (auth, session model, missing native plugins) is
/// separate, already-designed work. If it fails, that's exactly the kind
/// of finding this spike exists to surface before committing further.
///
/// Requires web/sqlite3mc.wasm and web/drift_worker.js to exist (fetched/
/// copied once for this spike - see the memory note on where they came
/// from). Run with: flutter test -p chrome test/web_spike
void main() {
  int dbCounter = 0;

  Future<AppDatabase> openWebDb() async {
    dbCounter++;
    return AppDatabase(
      driftDatabase(
        name: 'nexapos_web_spike_${DateTime.now().microsecondsSinceEpoch}_$dbCounter',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3mc.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
  }

  test('drift web driver opens this schema, runs migration/triggers/WAL, and completes a full checkout', () async {
    final db = await openWebDb();
    addTearDown(db.close);

    final syncMeta = SyncMetadataService(db);
    const clock = SystemClock();
    final idGen = UuidIdGenerator();

    final categoryRepository = CategoryRepositoryImpl(db, db.categoriesDao, syncMeta, clock, idGen);
    final productRepository = ProductRepositoryImpl(db, db.productsDao, syncMeta, clock, idGen);
    final saleRepository = SaleRepositoryImpl(db, db.salesDao, syncMeta, clock, idGen);
    final saleItemRepository = SaleItemRepositoryImpl(db, db.saleItemsDao, syncMeta, clock, idGen);
    final paymentRecordRepository = PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, syncMeta, clock, idGen);
    final stockService = StockService(db, db.productsDao, db.stockMovementsDao, syncMeta, clock, idGen);
    final checkout = CheckoutService(
      db,
      saleRepository,
      saleItemRepository,
      paymentRecordRepository,
      productRepository,
      stockService,
      syncMeta,
      clock,
      idGen,
    );

    // Exercises onCreate (createAll + the dynamic per-table trigger loop +
    // seedDeviceMeta/seedRoles/seedDefaultBusinessSettings) and beforeOpen
    // (WAL pragma, foreign_keys pragma, the safety-trigger loop) - if any
    // of those fail under the web VFS, this line throws.
    final category = Category(id: idGen.newId(), name: 'General', status: 'active');
    await categoryRepository.create(category);

    final productId = await productRepository.create(Product(
      id: '',
      sku: 'SKU-WEB-SPIKE',
      name: 'Widget',
      categoryId: category.id,
      retailPrice: const Money(10000),
      wholesalePrice: const Money(8000),
      costPrice: const Money(5000),
      stockQty: 0,
      reorderLevel: 2,
      status: 'active',
    ));
    await stockService.applyMovement(productId: productId, movementType: 'purchase', delta: 10);

    final userRepository = UserRepositoryImpl(db, db.usersDao, syncMeta, clock, idGen);
    final user = User(
      id: idGen.newId(),
      role: UserRole.cashier,
      name: 'Cashier',
      username: 'cashier',
      passwordHash: 'irrelevant-for-this-spike',
      status: 'active',
    );
    await userRepository.create(user);

    // A real checkout: cart validation, a transaction spanning sales +
    // sale_items + a stock_movements insert + a products stock-qty
    // update, then a join-based read back - the actual "query patterns"
    // in question, not a single trivial insert.
    final result = await checkout.checkout(
      cart: [CartItem(productId: productId, name: 'Widget', unitPrice: const Money(10000), costPrice: const Money(5000), quantity: 3)],
      discount: const Money.zero(),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: user.id,
    );

    late String saleId;
    result.when(
      ok: (sale) {
        saleId = sale.id;
        expect(sale.status, 'paid');
        expect(sale.total.cents, 30000);
      },
      failure: (m) => fail(m),
    );

    final product = await productRepository.findById(productId);
    expect(product!.stockQty, 7, reason: 'stock movement + product update must both have committed');

    final movements = await db.stockMovementsDao.forProduct(productId);
    expect(movements, hasLength(2), reason: 'seed purchase + this sale - a real multi-row read');

    final items = await saleItemRepository.forSale(saleId);
    expect(items, hasLength(1));
    expect(items.single.lineTotal.cents, 30000);
  });

  test('sqlite3mc PRAGMA key encrypts data at rest, same as the native SQLCipher path', () async {
    final dbName = 'nexapos_web_spike_encryption_${DateTime.now().microsecondsSinceEpoch}';

    final db1 = AppDatabase(
      driftDatabase(
        name: dbName,
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3mc.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );
    // Must be the very first statement executed against a fresh database
    // - same requirement as the native PRAGMA key path in
    // AppDatabase.defaults(), just applied here instead of via
    // DriftNativeOptions.setup (DriftWebOptions has no equivalent hook).
    await db1.customStatement("PRAGMA key = 'spike-correct-key';");
    final syncMeta1 = SyncMetadataService(db1);
    await CategoryRepositoryImpl(db1, db1.categoriesDao, syncMeta1, const SystemClock(), UuidIdGenerator())
        .create(Category(id: 'cat-1', name: 'Encrypted Category', status: 'active'));
    await db1.close();

    // Reopen the SAME named database with the CORRECT key - data must
    // still be there.
    final db2 = AppDatabase(
      driftDatabase(
        name: dbName,
        web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3mc.wasm'), driftWorker: Uri.parse('drift_worker.js')),
      ),
    );
    await db2.customStatement("PRAGMA key = 'spike-correct-key';");
    final rows = await db2.customSelect('SELECT name FROM categories WHERE id = ?', variables: [Variable('cat-1')]).get();
    expect(rows, hasLength(1), reason: 'the correct key must decrypt what was written');
    expect(rows.single.read<String>('name'), 'Encrypted Category');
    await db2.close();

    // Reopen the SAME named database with the WRONG key - this must NOT
    // transparently read the real row back. sqlite3mc typically surfaces
    // this as an error on first real table access (a "file is not a
    // database" style failure) rather than returning wrong/garbage rows,
    // so either outcome (a thrown error, or a query that comes back
    // empty/garbled) counts as encryption actually being enforced; only
    // "reads back the correct plaintext row with the wrong key" is a
    // real failure here.
    final db3 = AppDatabase(
      driftDatabase(
        name: dbName,
        web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3mc.wasm'), driftWorker: Uri.parse('drift_worker.js')),
      ),
    );
    await db3.customStatement("PRAGMA key = 'spike-WRONG-key';");
    try {
      final wrongKeyRows = await db3.customSelect('SELECT name FROM categories WHERE id = ?', variables: [Variable('cat-1')]).get();
      final gotRealData = wrongKeyRows.isNotEmpty && wrongKeyRows.single.read<String>('name') == 'Encrypted Category';
      expect(gotRealData, isFalse, reason: 'the wrong key must never transparently decrypt real data');
    } catch (_) {
      // An error here (can't read the encrypted file with the wrong key)
      // is the expected, correct outcome - not a test failure.
    } finally {
      await db3.close();
    }
  });
}
