import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/result.dart';
import '../../data/repositories/business_settings_repository_impl.dart';
import '../entities/business_settings.dart';
import '../repositories/business_settings_repository.dart';

part 'business_settings_service.g.dart';

const validPaperWidthsMm = {58, 80};

@Riverpod(keepAlive: true)
BusinessSettingsService businessSettingsService(Ref ref) {
  return BusinessSettingsService(ref.watch(businessSettingsRepositoryProvider));
}

class BusinessSettingsService {
  final BusinessSettingsRepository _repository;

  BusinessSettingsService(this._repository);

  Future<BusinessSettings> get() => _repository.get();

  Future<Result<BusinessSettings>> update({
    required String businessName,
    String? address,
    String? phone,
    String? receiptFooter,
    required String currency,
    required int paperWidthMm,
  }) async {
    final trimmedName = businessName.trim();
    if (trimmedName.isEmpty) return const Result.failure('Enter a business name.');
    final trimmedCurrency = currency.trim().toUpperCase();
    if (trimmedCurrency.isEmpty) return const Result.failure('Enter a currency code.');
    if (!validPaperWidthsMm.contains(paperWidthMm)) {
      return const Result.failure('Select a valid receipt paper width.');
    }

    final settings = BusinessSettings(
      businessName: trimmedName,
      address: _cleanOrNull(address),
      phone: _cleanOrNull(phone),
      receiptFooter: _cleanOrNull(receiptFooter),
      currency: trimmedCurrency,
      paperWidthMm: paperWidthMm,
    );
    await _repository.update(settings);
    return Result.ok(settings);
  }

  String? _cleanOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
