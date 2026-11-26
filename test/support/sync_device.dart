import 'package:drift/drift.dart';
import 'package:drift/native.dart';


import 'package:nexapos_mobile/core/utils/id_generator.dart';
import 'package:nexapos_mobile/core/utils/money.dart';
import 'package:nexapos_mobile/data/local/database.dart' hide Category, Product, User, Sale;
import 'package:nexapos_mobile/data/local/sync_metadata.dart';
import 'package:nexapos_mobile/data/repositories/category_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/expense_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/payment_record_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/product_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_item_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/sale_repository_impl.dart';
import 'package:nexapos_mobile/data/repositories/user_repository_impl.dart';
import 'package:nexapos_mobile/data/sync/platform_sync_gateway.dart';
import 'package:nexapos_mobile/domain/entities/cart_item.dart';
import 'package:nexapos_mobile/domain/entities/category.dart';
import 'package:nexapos_mobile/domain/entities/paystack_credentials.dart';
import 'package:nexapos_mobile/domain/entities/product.dart';
import 'package:nexapos_mobile/domain/entities/sale.dart';
import 'package:nexapos_mobile/domain/entities/user_role.dart';
import 'package:nexapos_mobile/domain/services/auth_service.dart';
import 'package:nexapos_mobile/domain/services/checkout_service.dart';
import 'package:nexapos_mobile/domain/services/paystack_credentials_service.dart';
import 'package:nexapos_mobile/domain/services/stock_service.dart';
import 'package:nexapos_mobile/domain/services/sync_service.dart';

import 'fake_shop_cloud.dart';
import 'shop_harness.dart' show HarnessClock;

const syncDeviceBaseUrl = 'http://cloud.test/index.php';

class _Credentials implements PaystackCredentialsService {
  @override
  Future<PaystackCredentials> load() async => const PaystackCredentials(
        baseUrl: syncDeviceBaseUrl,
        apiKey: 'device-key',
        currency: 'KES',
        defaultEmail: '',
      );
  @override
  Future<void> save(PaystackCredentials value) async {}
  @override
  Future<String> loadDeviceLabel() async => '';
  @override
  Future<void> saveDeviceLabel(String label) async {}
  @override
  Future<void> clearRegistration() async {}
}

/// One NexaPOS device of a shop for sync tests: its own database and the app's real repositories, checkout, stock and
/// sync, talking to a [FakeShopCloud] (when it can reach it) and to other devices over the "LAN" (the same export /
/// apply calls the LAN service makes).
class SyncDevice {
  SyncDevice._(this.name, this.db, this.meta, this.id, this.clock, this.cloud, this._open);

  final String name;
  final AppDatabase db;
  final SyncMetadataService meta;
  final String id;
  final HarnessClock clock;
  final FakeShopCloud cloud;
  final QueryExecutor Function() _open;

  /// False: this device has no internet (its requests fail as they do offline); it can still use the LAN.
  bool get hasInternet => !cloud.noInternet.contains(id);
  set hasInternet(bool value) => value ? cloud.noInternet.remove(id) : cloud.noInternet.add(id);

  late final SyncService sync = SyncService(db, meta, PlatformSyncGateway(cloud.client(id)), _Credentials());

  final _ids = UuidIdGenerator();
  late final products = ProductRepositoryImpl(db, db.productsDao, meta, clock, _ids);
  late final categories = CategoryRepositoryImpl(db, db.categoriesDao, meta, clock, _ids);
  late final users = UserRepositoryImpl(db, db.usersDao, meta, clock, _ids);
  late final expenses = ExpenseRepositoryImpl(db, db.expensesDao, meta, clock, _ids);
  late final stock = StockService(db, db.productsDao, db.stockMovementsDao, meta, clock, _ids);
  late final checkout = CheckoutService(
    db,
    SaleRepositoryImpl(db, db.salesDao, meta, clock, _ids),
    SaleItemRepositoryImpl(db, db.saleItemsDao, meta, clock, _ids),
    PaymentRecordRepositoryImpl(db, db.paymentRecordsDao, meta, clock, _ids),
    products,
    stock,
    meta,
    clock,
    _ids,
  );

  static Future<SyncDevice> create(
    String name,
    FakeShopCloud cloud,
    HarnessClock clock, {
    QueryExecutor Function()? open,
  }) async {
    final opener = open ?? NativeDatabase.memory;
    final db = AppDatabase(opener());
    final meta = SyncMetadataService(db);
    return SyncDevice._(name, db, meta, await meta.deviceId(), clock, cloud, opener);
  }

  /// The same device after its app was closed and opened again (an update, a restart): the same database file.
  Future<SyncDevice> restart() async {
    await db.close();
    final again = await create(name, cloud, clock, open: _open);
    again.hasInternet = hasInternet;
    return again;
  }

  /// The shop's first device: an owner who can sell.
  Future<void> openShop() async {
    final made = await AuthService(users, _ids).createUser(
      name: 'Owner',
      username: 'owner',
      password: 'long-password',
      role: UserRole.admin,
    );
    made.when(ok: (_) {}, failure: (m) => throw StateError(m));
  }

  /// Joins the shop: what joining with an invite code does (everything comes down from the shop).
  Future<void> join() async {
    await sync.prepareJoinedShop();
    await sync.pullRemoteChanges(syncDeviceBaseUrl, 'device-key');
    await db.customStatement("DELETE FROM local_safety_state WHERE id='shop_hydration'");
  }

  /// One routine sync with the cloud, as the app runs it every few minutes: what this device has, up; then the shop's
  /// changes, down.
  Future<void> syncWithCloud() async {
    await sync.pushLocalChanges(syncDeviceBaseUrl, 'device-key');
    await sync.pullRemoteChanges(syncDeviceBaseUrl, 'device-key');
  }

  /// Everything [other] has that this device does not, over the LAN (500 at a time, as the LAN service pulls).
  Future<int> takeOverLan(SyncDevice other) async {
    var taken = 0;
    while (true) {
      final changes = await other.sync.exportLanChanges(await sync.lanRevisionCursors());
      if (changes.isEmpty) return taken;
      await sync.applyLanChanges(changes);
      taken += changes.length;
    }
  }

  Future<String> addCategory(String name) async {
    final categoryId = _ids.newId();
    await categories.create(Category(id: categoryId, name: name, status: 'active'));
    return categoryId;
  }

  Future<String> addProduct(String name, String categoryId, int price, int stockQty) async {
    final productId = await products.create(Product(
      id: '',
      sku: 'SKU-$name-${_ids.newId().substring(0, 6)}',
      name: name,
      categoryId: categoryId,
      retailPrice: Money(price),
      wholesalePrice: Money(price),
      costPrice: Money(price ~/ 2),
      stockQty: 0,
      reorderLevel: 1,
      status: 'active',
    ));
    await stock.applyMovement(productId: productId, movementType: 'purchase', delta: stockQty);
    return productId;
  }

  Future<void> setPrice(String productId, int price) async {
    final product = (await products.findById(productId))!;
    await products.update(product.copyWith(retailPrice: Money(price)));
  }

  Future<Sale> sell(String productId, int quantity) async {
    final product = (await products.findById(productId))!;
    final seller = (await db.select(db.users).get()).firstWhere((u) => u.status == 'active');
    final result = await checkout.checkout(
      cart: [
        CartItem(
          productId: product.id,
          name: product.name,
          unitPrice: product.retailPrice,
          costPrice: product.costPrice,
          quantity: quantity,
        ),
      ],
      discount: const Money(0),
      saleType: 'retail',
      paymentMethod: 'cash',
      userId: seller.id,
    );
    return result.when(ok: (s) => s, failure: (m) => throw StateError('$name could not sell: $m'));
  }

  Future<int> waiting() async => (await sync.health()).pendingChanges;

  /// Every row of [table], by id, as this device holds it.
  Future<Map<String, Map<String, Object?>>> rows(String table) async {
    final found = await db.customSelect('SELECT * FROM "$table" ORDER BY id').get();
    return {for (final row in found) row.read<String>('id'): row.data};
  }
}
