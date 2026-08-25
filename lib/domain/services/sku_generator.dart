import 'dart:math';
import '../../core/utils/id_generator.dart';
import '../repositories/product_repository.dart';

/// Shared by [ProductService] (manual add) and [CatalogImportService]
/// (xlsx import) so both creation paths mint SKUs the same way instead
/// of drifting into two different formats.
class SkuGenerator {
  static final _random = Random();

  static Future<String> generate(
    String seed,
    ProductRepository repository,
    IdGenerator idGenerator,
  ) async {
    final trimmed = seed.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final prefix = trimmed.isEmpty ? 'PRD' : trimmed.padRight(3, 'X').substring(0, 3);
    for (var attempt = 0; attempt < 20; attempt++) {
      final suffix = (_random.nextInt(90000) + 10000).toString();
      final candidate = '$prefix-$suffix';
      if (await repository.findBySku(candidate) == null) return candidate;
    }
    return '$prefix-${idGenerator.newId().substring(0, 8)}';
  }
}
