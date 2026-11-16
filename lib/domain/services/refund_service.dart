import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/providers.dart';
import '../../core/result.dart';
import '../../core/utils/id_generator.dart';
import '../../core/utils/money.dart';
import '../../data/local/database.dart'
    hide Sale, SaleItem, PaymentRecord, User;
import '../../data/repositories/payment_record_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/sale_item_repository_impl.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../entities/payment_record.dart';
import '../entities/sale.dart';
import '../entities/sale_item.dart';
import '../entities/user.dart';
import '../entities/user_role.dart';
import '../repositories/payment_record_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/sale_item_repository.dart';
import '../repositories/sale_repository.dart';
import 'checkout_service.dart';
import 'lan_sync_service.dart';
import 'sensitive_action_service.dart';
import 'session_service.dart';
import 'stock_service.dart';
import 'sync_service.dart';

part 'refund_service.g.dart';

/// The wording of the password prompt, and what an [ActionApproval] for a refund is for.
const refundApprovalAction = 'Refund a sale';

/// Who may refund: an administrator or a manager (who re-types their own password first).
const refundRoles = {UserRole.admin, UserRole.manager};

/// The longest reason that is kept (it travels in the sale's own record).
const maxRefundReasonLength = 200;

@Riverpod(keepAlive: true)
RefundService refundService(Ref ref) {
  final checkout = ref.watch(checkoutServiceProvider);
  return RefundService(
    ref.watch(appDatabaseProvider),
    ref.watch(saleRepositoryProvider),
    ref.watch(saleItemRepositoryProvider),
    ref.watch(paymentRecordRepositoryProvider),
    ref.watch(productRepositoryProvider),
    ref.watch(stockServiceProvider),
    ref.watch(sensitiveActionProvider),
    ref.watch(idGeneratorProvider),
    newSaleNumber: checkout.generateSaleNumber,
    currentUser: () => ref.read(sessionProvider),
    onRefundCommitted: () async {
      await Future.wait([
        ref.read(syncServiceProvider).runSyncCycle(),
        ref.read(lanSyncServiceProvider).syncNow(),
      ]);
    },
  );
}

/// round(a * b / c) for non-negative whole numbers, exactly (the web build's integers are doubles, which
/// cannot hold the product of two large amounts of cents).
int roundedShare(int a, int b, int c) {
  if (c <= 0) return 0;
  final numerator = BigInt.from(a) * BigInt.from(b) * BigInt.two + BigInt.from(c);
  return (numerator ~/ (BigInt.two * BigInt.from(c))).toInt();
}

/// One line of the original sale and how much of it has already been given back.
class RefundableLine {
  final SaleItem item;
  final int refunded;

  const RefundableLine(this.item, this.refunded);

  int get remaining => item.quantity - refunded;
}

/// A sale with everything the refund screen needs: its lines, what is left to refund on each, and what has
/// been refunded so far (all amounts here are positive: money that went back to the customer).
class RefundableSale {
  final Sale sale;
  final List<RefundableLine> lines;
  final List<Sale> refunds;

  const RefundableSale({
    required this.sale,
    required this.lines,
    required this.refunds,
  });

  Money get refundedTotal =>
      Money(refunds.fold<int>(0, (sum, r) => sum - r.total.cents));

  Money get refundedSubtotal =>
      Money(refunds.fold<int>(0, (sum, r) => sum - r.subtotal.cents));

  Money get refundedDiscount =>
      Money(refunds.fold<int>(0, (sum, r) => sum - r.discount.cents));

  Money get refundedCash =>
      Money(refunds.fold<int>(0, (sum, r) => sum - (r.cashReceived?.cents ?? 0)));

  bool get hasAnythingLeft => lines.any((l) => l.remaining > 0);

  /// Whether this sale may be refunded at all (the reason, when not, is [whyNot]).
  String? get whyNot {
    if (sale.isRefund) return 'A refund cannot be refunded.';
    if (!sale.isPaid) return 'Only a paid sale can be refunded.';
    if (!hasAnythingLeft) return 'This sale has already been refunded in full.';
    return null;
  }

  Money get remainingTotal => sale.total - refundedTotal;
}

/// What the person chose to give back from one line, and whether the goods go back on the shelf.
class RefundChoice {
  final String itemId;
  final int quantity;
  final bool restock;

  const RefundChoice({
    required this.itemId,
    required this.quantity,
    this.restock = true,
  });
}

/// The money for a set of choices (positive amounts), worked out exactly as it will be recorded.
class RefundQuote {
  final Money subtotal;
  final Money discount;
  final Money total;

  /// For a sale paid partly in cash and partly by M-Pesa: how much of this refund goes back as cash.
  final Money? cash;

  const RefundQuote({
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.cash,
  });
}

class _RefundAbort implements Exception {
  final String message;
  const _RefundAbort(this.message);
}

/// Gives money back for an earlier sale. A refund is recorded as its OWN sale with negative amounts (see
/// sales_table.dart for why), with a negative line for each item given back, a stock 'return' for each item
/// that goes back on the shelf, and (for M-Pesa) a payment record. The original sale is never changed.
class RefundService {
  final AppDatabase _db;
  final SaleRepository _saleRepository;
  final SaleItemRepository _saleItemRepository;
  final PaymentRecordRepository _paymentRecordRepository;
  final ProductRepository _productRepository;
  final StockService _stockService;
  final SensitiveActionService _auth;
  final IdGenerator _idGenerator;
  final Future<String> Function() newSaleNumber;
  final User? Function() currentUser;
  final Future<void> Function()? onRefundCommitted;

  RefundService(
    this._db,
    this._saleRepository,
    this._saleItemRepository,
    this._paymentRecordRepository,
    this._productRepository,
    this._stockService,
    this._auth,
    this._idGenerator, {
    required this.newSaleNumber,
    required this.currentUser,
    this.onRefundCommitted,
  });

  /// Whether the person logged in may refund at all (the button is hidden for anyone else).
  bool get canRefund {
    final user = currentUser();
    return user != null && user.isActive && refundRoles.contains(user.role);
  }

  /// The sale with its lines and what has been refunded so far, or null when there is no such sale.
  Future<RefundableSale?> refundableSale(String saleId) async {
    final sale = await _saleRepository.findById(saleId);
    if (sale == null) return null;
    final lines = await _saleItemRepository.forSale(saleId);
    final refunds = await _saleRepository.refundsOf(saleId);
    final given = <String, int>{};
    for (final refund in refunds) {
      for (final line in await _saleItemRepository.forSale(refund.id)) {
        final of = line.refundOfItemId;
        if (of == null) continue;
        given[of] = (given[of] ?? 0) - line.quantity;
      }
    }
    return RefundableSale(
      sale: sale,
      lines: [for (final l in lines) RefundableLine(l, given[l.id] ?? 0)],
      refunds: refunds,
    );
  }

  /// The money for [choices], or the plain-words reason they cannot be refunded. Pure: nothing is written.
  Result<RefundQuote> quote(RefundableSale source, List<RefundChoice> choices) {
    final blocked = source.whyNot;
    if (blocked != null) return Result.failure(blocked);

    final byId = {for (final l in source.lines) l.item.id: l};
    final seen = <String>{};
    var subtotal = 0;
    for (final choice in choices) {
      final line = byId[choice.itemId];
      if (line == null) {
        return const Result.failure('That item is not part of this sale.');
      }
      if (!seen.add(choice.itemId)) {
        return const Result.failure('An item is listed twice.');
      }
      if (choice.quantity < 1) {
        return const Result.failure('Enter a quantity of 1 or more.');
      }
      if (line.remaining < 1) {
        return Result.failure('${line.item.itemName} has already been refunded.');
      }
      if (choice.quantity > line.remaining) {
        return Result.failure(
          'Only ${line.remaining} of ${line.item.itemName} can still be refunded.',
        );
      }
      subtotal += choice.quantity * line.item.unitPrice.cents;
    }
    if (choices.isEmpty) {
      return const Result.failure('Choose at least one item to refund.');
    }

    final sale = source.sale;
    // The discount is given back in proportion to the goods, in whole cents, so that the refunds of one sale
    // always add up to exactly what the customer paid (the last one takes the rounding).
    final cumulativeSubtotal = source.refundedSubtotal.cents + subtotal;
    final discountTarget = roundedShare(
      sale.discount.cents,
      cumulativeSubtotal,
      sale.subtotal.cents,
    );
    var discount = discountTarget - source.refundedDiscount.cents;
    if (discount < 0) discount = 0;
    if (discount > subtotal) discount = subtotal;
    final total = subtotal - discount;
    if (total < 1) {
      return const Result.failure('There is nothing to refund on those items.');
    }

    Money? cash;
    if (sale.isSplitPayment) {
      final cumulativeTotal = source.refundedTotal.cents + total;
      final target = roundedShare(
        sale.cashReceived!.cents,
        cumulativeTotal,
        sale.total.cents,
      );
      var share = target - source.refundedCash.cents;
      if (share < 0) share = 0;
      if (share > total) share = total;
      cash = Money(share);
    }
    return Result.ok(
      RefundQuote(
        subtotal: Money(subtotal),
        discount: Money(discount),
        total: Money(total),
        cash: cash,
      ),
    );
  }

  /// Records the refund. [approval] is the password re-entry the refund screen asks for (see
  /// [refundApprovalAction] and [refundRoles]). Returns the refund's own sale (open its receipt).
  Future<Result<Sale>> refund({
    required String saleId,
    required List<RefundChoice> choices,
    required String reason,
    required ActionApproval approval,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      return const Result.failure('Enter the reason for the refund.');
    }
    if (cleanReason.length > maxRefundReasonLength) {
      return const Result.failure(
        'The reason is too long (200 characters at most).',
      );
    }
    final user = currentUser();
    if (user == null) return const Result.failure('Log in first.');
    if (!canRefund) {
      return const Result.failure('Only an administrator or a manager can refund.');
    }
    // Check the whole refund BEFORE the one-time approval is spent on it.
    final firstLook = await refundableSale(saleId);
    if (firstLook == null) return const Result.failure('Sale not found.');
    final firstProblem = quote(firstLook, choices).when(
      ok: (_) => null,
      failure: (message) => message,
    );
    if (firstProblem != null) return Result.failure(firstProblem);
    try {
      await _auth.consume(approval, refundApprovalAction);
    } catch (e) {
      return Result.failure(e is StateError ? e.message : '$e');
    }

    final refundId = _idGenerator.newId();
    final refundNumber = await newSaleNumber();
    try {
      await _db.transaction(() async {
        // Worked out again inside the transaction: two refunds of the same sale started together must not
        // both get through.
        final source = await refundableSale(saleId);
        if (source == null) throw const _RefundAbort('Sale not found.');
        final checked = quote(source, choices);
        final amounts = checked.when(
          ok: (q) => q,
          failure: (message) => throw _RefundAbort(message),
        );
        final sale = source.sale;
        final byId = {for (final l in source.lines) l.item.id: l.item};

        final lines = <SaleItem>[];
        final goesBack = <({String productId, int quantity})>[];
        for (final choice in choices) {
          final original = byId[choice.itemId]!;
          var restocked = false;
          final productId = original.productId;
          if (choice.restock && productId != null) {
            restocked = await _productRepository.findById(productId) != null;
          }
          lines.add(
            SaleItem(
              id: _idGenerator.newId(),
              saleId: refundId,
              productId: productId,
              itemName: original.itemName,
              quantity: -choice.quantity,
              unitPrice: original.unitPrice,
              // The cost only comes back when the goods do: stock thrown away stays a cost of the shop.
              costPrice: restocked ? original.costPrice : const Money.zero(),
              lineTotal: Money(-choice.quantity * original.unitPrice.cents),
              refundOfItemId: original.id,
            ),
          );
          if (restocked) {
            goesBack.add((productId: productId!, quantity: choice.quantity));
          }
        }

        await _saleRepository.create(
          Sale(
            id: refundId,
            saleNumber: refundNumber,
            userId: user.id,
            customerName: sale.customerName,
            customerPhone: sale.customerPhone,
            saleType: 'refund',
            paymentMethod: sale.paymentMethod,
            subtotal: Money(-amounts.subtotal.cents),
            discount: Money(-amounts.discount.cents),
            total: Money(-amounts.total.cents),
            status: 'paid',
            createdAt: DateTime.now(),
            cashReceived: amounts.cash == null ? null : Money(-amounts.cash!.cents),
            refundOfSaleId: sale.id,
            refundReason: cleanReason,
          ),
        );
        await _saleItemRepository.createMany(lines);
        for (final back in goesBack) {
          final movement = await _stockService.applyMovement(
            productId: back.productId,
            movementType: 'return',
            delta: back.quantity,
            note: 'Refund $refundNumber',
            userId: user.id,
          );
          movement.when(
            ok: (_) {},
            failure: (message) => throw _RefundAbort(message),
          );
        }
        if (sale.paymentMethod != 'cash') {
          await _paymentRecordRepository.create(
            PaymentRecord(
              id: '',
              saleId: refundId,
              method: sale.paymentMethod,
              amount: Money(-amounts.total.cents),
              referenceNote: 'Refund of ${sale.saleNumber}',
              status: 'refunded',
            ),
          );
        }
      });
    } on _RefundAbort catch (abort) {
      return Result.failure(abort.message);
    }

    final done = await _saleRepository.findById(refundId);
    final callback = onRefundCommitted;
    if (callback != null) {
      unawaited(callback().catchError((Object _) {}));
    }
    return Result.ok(done!);
  }
}
