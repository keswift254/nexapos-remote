// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thermal_printer_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which physical printer to use for "Print Receipt" is inherently a
/// per-device/per-counter fact (a shop with 3 tills has 3 different
/// printers), never a shop-wide fact - so this lives in the same
/// device-local secure storage as the sync/Paystack baseUrl and api_key,
/// never in the synced business_settings table.

@ProviderFor(thermalPrinterService)
final thermalPrinterServiceProvider = ThermalPrinterServiceProvider._();

/// Which physical printer to use for "Print Receipt" is inherently a
/// per-device/per-counter fact (a shop with 3 tills has 3 different
/// printers), never a shop-wide fact - so this lives in the same
/// device-local secure storage as the sync/Paystack baseUrl and api_key,
/// never in the synced business_settings table.

final class ThermalPrinterServiceProvider
    extends
        $FunctionalProvider<
          ThermalPrinterService,
          ThermalPrinterService,
          ThermalPrinterService
        >
    with $Provider<ThermalPrinterService> {
  /// Which physical printer to use for "Print Receipt" is inherently a
  /// per-device/per-counter fact (a shop with 3 tills has 3 different
  /// printers), never a shop-wide fact - so this lives in the same
  /// device-local secure storage as the sync/Paystack baseUrl and api_key,
  /// never in the synced business_settings table.
  ThermalPrinterServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thermalPrinterServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thermalPrinterServiceHash();

  @$internal
  @override
  $ProviderElement<ThermalPrinterService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ThermalPrinterService create(Ref ref) {
    return thermalPrinterService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThermalPrinterService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThermalPrinterService>(value),
    );
  }
}

String _$thermalPrinterServiceHash() =>
    r'a45214f3aa66b252e323f88a6b8757e424b63de0';
