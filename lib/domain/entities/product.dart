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
    required Money retailPrice,
    required Money wholesalePrice,
    required Money costPrice,
    required int stockQty,
    required int reorderLevel,
    required String status,
  }) = _Product;

  const Product._();

  bool get isActive => status == 'active';

  bool get isLowStock => stockQty <= reorderLevel;
}
