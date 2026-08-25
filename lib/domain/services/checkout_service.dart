import 'dart:math';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../data/local/database.dart' hide Sale, SaleItem, PaymentRecord;
import '../../data/local/sync_metadata.dart';
import '../../data/repositories/payment_record_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/sale_item_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../entities/cart_item.dart';
import '../entities/payment_record.dart';
import '../entities/sale.dart';
import '../entities/sale_item.dart';
import '../repositories/payment_record_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sale_item_repository.dart';
import '../repositories/sale_repository.dart';
import 'stock_service.dart';

part 'checkout_service.g.dart';

@Riverpod(keepAlive: true)
CheckoutService checkoutService(Ref ref) {
  return CheckoutService(
    ref.watch(appDatabaseProvider),
    ref.watch(saleRepositoryProvider),
    ref.watch(saleItemRepositoryProvider),
    ref.watch(paymentRecordRepositoryProvider),
    ref.watch(productRepositoryProvider),
    ref.watch(stockServiceProvider),
    ref.watch(syncMetadataProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  );
}

const paymentMethods = ['cash', 'mpesa', 'mpesa_manual', 'paystack'];
const saleTypes = ['retail', 'wholesale'];

class CheckoutTotals {
  final Money subtotal;
  final Money discount;
  final Money total;

  const CheckoutTotals({required this.subtotal, required this.discount, required this.total});
}

class _ValidatedCart {
  final List<CartItem> items;
  final Money subtotal;

  const _ValidatedCart({required this.items, required this.subtotal});
}

class _CheckoutAbort implements Exception {
  final String message;
  const _CheckoutAbort(this.message);
}

/// Dart port of PHP's checkout route (public/index.php): same cart
/// validation, same merge-duplicate-product-lines behavior, same
/// stock-guard messages, same subtotal/discount-clamp/total math.
///
/// Two payment lifecycles, matching the plan's "no online gateway
/// while offline" note:
/// - cash/mpesa/mpesa_manual: [checkout] records the sale as 'paid'
///   immediately - there is no confirmation to wait for.
/// - paystack: a genuinely real gateway round-trip (see
///   PaystackPaymentService), so it needs three steps instead of one -
///   [beginPaystackSale] reserves stock and records the sale as
///   'pending' *after* the gateway checkout has already been created,
///   then [finalizePaystackSale] or [cancelPaystackSale] resolves it
///   once the customer has paid or the cashier gives up waiting.
class CheckoutService {
  final AppDatabase _db;
  final SaleRepository _saleRepository;
  final SaleItemRepository _saleItemRepository;
  final PaymentRecordRepository _paymentRecordRepository;
  final ProductRepository _productRepository;
  final StockService _stockService;
  final SyncMetadataService _syncMeta;
  final Clock _clock;
  final IdGenerator _idGenerator;

  CheckoutService(
    this._db,
    this._saleRepository,
    this._saleItemRepository,
    this._paymentRecordRepository,
    this._productRepository,
    this._stockService,
    this._syncMeta,
    this._clock,
    this._idGenerator,
  );

  /// `<device-short-code>-<yyyyMMddHHmmss>-<4-char-random>`, fixing the
  /// collision risk in PHP's `'S' . date('YmdHis')` (one-second
  /// resolution, no random suffix - confirmed at public/index.php:325).
  /// Exposed publicly because PaystackPaymentService needs a sale number
  /// up front, to use as the gateway's transaction reference *before*
  /// the sale row exists.
  Future<String> generateSaleNumber() async {
    final deviceId = await _syncMeta.deviceId();
    final shortCode = deviceId.replaceAll('-', '').substring(0, 6).toUpperCase();
    final timestamp = DateFormat('yyyyMMddHHmmss').format(_clock.now());
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final suffix = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$shortCode-$timestamp-$suffix';
  }

  /// Read-only cart validation + totals, for the cart screen to show a
  /// live running total before the cashier taps checkout.
  Future<Result<CheckoutTotals>> previewTotals(List<CartItem> cart, Money discount) async {
    try {
      final validated = await _validateCart(cart);
      return Result.ok(_computeTotals(validated.subtotal, discount));
    } on _CheckoutAbort catch (e) {
      return Result.failure(e.message);
    }
  }

  /// cash/mpesa/mpesa_manual only - paystack must go through
  /// [beginPaystackSale] since it needs a real gateway round-trip
  /// before anything is written.
  Future<Result<Sale>> checkout({
    required List<CartItem> cart,
    required Money discount,
    String customerName = '',
    String customerPhone = '',
    required String saleType,
    required String paymentMethod,
    String? referenceNote,
    required String userId,
  }) async {
    if (!saleTypes.contains(saleType)) return const Result.failure('Select a valid sale type.');
    if (!paymentMethods.contains(paymentMethod) || paymentMethod == 'paystack') {
      return const Result.failure('Select a valid payment method.');
    }

    final _ValidatedCart validated;
    try {
      validated = await _validateCart(cart);
    } on _CheckoutAbort catch (e) {
      return Result.failure(e.message);
    }

    final isExternal = paymentMethod == 'mpesa' || paymentMethod == 'mpesa_manual';
    final totals = _computeTotals(validated.subtotal, discount);
    final saleNumber = await generateSaleNumber();
    final saleId = _idGenerator.newId();
    final trimmedPhone = customerPhone.trim();

    final sale = Sale(
      id: saleId,
      saleNumber: saleNumber,
      userId: userId,
      customerName: customerName.trim().isEmpty ? 'Walk-in customer' : customerName.trim(),
      customerPhone: isExternal && trimmedPhone.isNotEmpty ? trimmedPhone : null,
      saleType: saleType,
      paymentMethod: paymentMethod,
      subtotal: totals.subtotal,
      discount: totals.discount,
      total: totals.total,
      status: 'paid',
      createdAt: _clock.now(),
    );

    try {
      await _db.transaction(() async {
        await _saleRepository.create(sale);
        await _insertItemsAndStock(saleId, saleNumber, validated.items, userId);
        if (isExternal) {
          final trimmedNote = referenceNote?.trim();
          await _paymentRecordRepository.create(PaymentRecord(
            id: '',
            saleId: saleId,
            method: paymentMethod,
            amount: totals.total,
            referenceNote: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
            status: 'paid',
          ));
        }
      });
    } on _CheckoutAbort catch (e) {
      return Result.failure(e.message);
    }

    return Result.ok(sale);
  }

  /// Called only after PaystackPaymentService has already created a
  /// real checkout session with Paystack and obtained [paystackReference]
  /// - this method's job is purely to reserve stock and record the sale
  /// as pending, atomically, so no other sale can oversell the same
  /// stock while this customer's payment is in flight.
  Future<Result<Sale>> beginPaystackSale({
    required List<CartItem> cart,
    required Money discount,
    String customerName = '',
    String customerPhone = '',
    required String saleType,
    required String userId,
    required String saleNumber,
    required String paystackReference,
  }) async {
    if (!saleTypes.contains(saleType)) return const Result.failure('Select a valid sale type.');

    final _ValidatedCart validated;
    try {
      validated = await _validateCart(cart);
    } on _CheckoutAbort catch (e) {
      return Result.failure(e.message);
    }

    final totals = _computeTotals(validated.subtotal, discount);
    final saleId = _idGenerator.newId();
    final trimmedPhone = customerPhone.trim();

    final sale = Sale(
      id: saleId,
      saleNumber: saleNumber,
      userId: userId,
      customerName: customerName.trim().isEmpty ? 'Walk-in customer' : customerName.trim(),
      customerPhone: trimmedPhone.isEmpty ? null : trimmedPhone,
      saleType: saleType,
      paymentMethod: 'paystack',
      subtotal: totals.subtotal,
      discount: totals.discount,
      total: totals.total,
      status: 'pending',
      createdAt: _clock.now(),
    );

    try {
      await _db.transaction(() async {
        await _saleRepository.create(sale);
        await _insertItemsAndStock(saleId, saleNumber, validated.items, userId);
        await _paymentRecordRepository.create(PaymentRecord(
          id: '',
          saleId: saleId,
          method: 'paystack',
          amount: totals.total,
          referenceNote: paystackReference,
          status: 'initiated',
        ));
      });
    } on _CheckoutAbort catch (e) {
      return Result.failure(e.message);
    }

    return Result.ok(sale);
  }

  /// Idempotent: calling this again on an already-resolved sale is a
  /// no-op that just returns the current row, since the poll loop in
  /// PaystackPaymentService may call this more than once in a race.
  Future<Result<Sale>> finalizePaystackSale(String saleId) async {
    final sale = await _saleRepository.findById(saleId);
    if (sale == null) return const Result.failure('Sale not found.');
    if (!sale.isPending) return Result.ok(sale);

    await _db.transaction(() async {
      await _saleRepository.updateStatus(saleId, 'paid');
      final record = await _paymentRecordRepository.forSale(saleId);
      if (record != null) {
        await _paymentRecordRepository.updateStatus(record.id, 'paid');
      }
    });

    return Result.ok(sale.copyWith(status: 'paid'));
  }

  /// Restores the stock [beginPaystackSale] reserved (as 'return'
  /// movements, the same movement-type vocabulary used everywhere else
  /// in this app - see stock_movements_table.dart) and marks the sale
  /// cancelled. Also idempotent, for the same reason as above.
  Future<Result<void>> cancelPaystackSale(String saleId, {String reason = 'Paystack payment not completed'}) async {
    final sale = await _saleRepository.findById(saleId);
    if (sale == null) return const Result.failure('Sale not found.');
    if (!sale.isPending) return const Result.ok(null);

    final items = await _saleItemRepository.forSale(saleId);
    await _db.transaction(() async {
      for (final item in items) {
        final productId = item.productId;
        if (productId == null) continue;
        await _stockService.applyMovement(
          productId: productId,
          movementType: 'return',
          delta: item.quantity,
          note: reason,
        );
      }
      await _saleRepository.updateStatus(saleId, 'cancelled');
      final record = await _paymentRecordRepository.forSale(saleId);
      if (record != null) {
        await _paymentRecordRepository.updateStatus(record.id, 'failed');
      }
    });

    return const Result.ok(null);
  }

  /// Sales left stranded in 'pending' by the app being killed outright
  /// while PaystackWaitingScreen was still polling - see
  /// PaystackPaymentService.reconcilePendingSales.
  Future<List<Sale>> pendingPaystackSales() => _saleRepository.findPendingPaystack();

  /// The gateway reference beginPaystackSale stashed in the payment
  /// record's referenceNote - needed to re-poll a sale found by
  /// [pendingPaystackSales], since PaystackWaitingScreen's own session
  /// object (and the checkout page's authorizationUrl) doesn't survive
  /// an app restart.
  Future<String?> paystackReferenceFor(String saleId) async {
    final record = await _paymentRecordRepository.forSale(saleId);
    return record?.referenceNote;
  }

  Future<void> _insertItemsAndStock(
    String saleId,
    String saleNumber,
    List<CartItem> items,
    String userId,
  ) async {
    final saleItems = items
        .map((item) => SaleItem(
              id: _idGenerator.newId(),
              saleId: saleId,
              productId: item.productId,
              itemName: item.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              costPrice: item.costPrice,
              lineTotal: item.lineTotal,
            ))
        .toList();
    await _saleItemRepository.createMany(saleItems);

    for (final item in items) {
      final productId = item.productId;
      if (productId == null) continue;
      final movement = await _stockService.applyMovement(
        productId: productId,
        movementType: 'sale',
        delta: -item.quantity,
        note: 'Sale $saleNumber',
        userId: userId,
      );
      if (movement.isFailure) {
        movement.when(ok: (_) {}, failure: (message) => throw _CheckoutAbort(message));
      }
    }
  }

  CheckoutTotals _computeTotals(Money subtotal, Money discount) {
    final nonNegativeDiscount = discount.isNegative ? const Money.zero() : discount;
    final clampedDiscount = nonNegativeDiscount > subtotal ? subtotal : nonNegativeDiscount;
    final total = subtotal - clampedDiscount;
    return CheckoutTotals(
      subtotal: subtotal,
      discount: clampedDiscount,
      total: total.isNegative ? const Money.zero() : total,
    );
  }

  /// Mirrors PHP's validatedItems loop: manual lines are trusted as
  /// entered (no stock concept), product lines re-fetch the product
  /// fresh (never trusting a stale cart-time snapshot for status/stock),
  /// and multiple cart lines for the same product are merged - summed
  /// quantity, latest-entered price wins, same convention used by the
  /// xlsx importer's duplicate-row merge.
  Future<_ValidatedCart> _validateCart(List<CartItem> cart) async {
    if (cart.isEmpty) throw const _CheckoutAbort('Add at least one product to the sale.');

    final mergedByProduct = <String, CartItem>{};
    final manualItems = <CartItem>[];
    for (final item in cart) {
      if (item.isManual) {
        final name = item.name.trim();
        if (name.isEmpty) throw const _CheckoutAbort('Enter the manual item name.');
        if (item.quantity < 1) throw const _CheckoutAbort('Manual item quantity must be at least 1.');
        if (item.unitPrice.isNegative || item.unitPrice.isZero) {
          throw const _CheckoutAbort('Manual item price must be greater than 0.');
        }
        manualItems.add(item);
        continue;
      }
      final productId = item.productId!;
      if (item.quantity < 1) {
        throw const _CheckoutAbort('Each sale item must have a valid product and quantity.');
      }
      final existing = mergedByProduct[productId];
      mergedByProduct[productId] = existing == null
          ? item
          : existing.copyWith(quantity: existing.quantity + item.quantity, unitPrice: item.unitPrice);
    }

    final validated = <CartItem>[...manualItems];
    for (final item in mergedByProduct.values) {
      final product = await _productRepository.findById(item.productId!);
      if (product == null || !product.isActive) {
        throw const _CheckoutAbort('One of the selected products is no longer available.');
      }
      if (product.stockQty < 1) {
        throw _CheckoutAbort('${product.name} is out of stock.');
      }
      if (item.quantity > product.stockQty) {
        throw _CheckoutAbort('Only ${product.stockQty} ${product.name} in stock.');
      }
      validated.add(item.copyWith(name: product.name, costPrice: product.costPrice));
    }

    final subtotal = validated.fold(const Money.zero(), (sum, item) => sum + item.lineTotal);
    return _ValidatedCart(items: validated, subtotal: subtotal);
  }
}
