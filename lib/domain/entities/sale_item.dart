import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'sale_item.freezed.dart';

/// [productId] is nullable for manual (non-catalog) items. [itemName] and
/// [costPrice] are snapshotted at sale time so a later product rename or
/// price change never rewrites history - matches PHP's sale_items
/// intent, which is why this table stores its own name/cost rather than
/// joining to products for them.
@freezed
abstract class SaleItem with _$SaleItem {
  const factory SaleItem({
    required String id,
    required String saleId,
    String? productId,
    required String itemName,
    required int quantity,
    required Money unitPrice,
    required Money costPrice,
    required Money lineTotal,
  }) = _SaleItem;

  const SaleItem._();
}
