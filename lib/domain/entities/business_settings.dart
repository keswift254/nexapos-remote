import 'package:freezed_annotation/freezed_annotation.dart';

part 'business_settings.freezed.dart';

@freezed
abstract class BusinessSettings with _$BusinessSettings {
  const factory BusinessSettings({
    required String businessName,
    String? address,
    String? phone,
    String? receiptFooter,
    required String currency,
    required int paperWidthMm,
  }) = _BusinessSettings;

  const BusinessSettings._();
}
