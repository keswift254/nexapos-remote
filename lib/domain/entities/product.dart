import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/utils/money.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory Product({
    required String id,
    required String sku,
    required String name,
    required String categoryId,
    String? imagePath,
    String? barcode,
    required Money retailPrice,
    required Money wholesalePrice,
    required Money costPrice,
    required int stockQty,
    required int reorderLevel,
    required String status,
  }) = _Product;

  const Product._();

  bool get isActive => status == 'active';

  /// The price this product sells at for [saleType] ('retail' or 'wholesale').
  /// A product whose wholesale price was never filled in (it is saved as zero)
  /// sells at its retail price rather than for nothing.
  Money priceFor(String saleType) => saleType == 'wholesale' && wholesalePrice > const Money.zero()
      ? wholesalePrice
      : retailPrice;

  bool get isLowStock => stockQty <= reorderLevel;
}
