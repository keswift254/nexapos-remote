// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reportData)
final reportDataProvider = ReportDataFamily._();

final class ReportDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReportData>,
          ReportData,
          FutureOr<ReportData>
        >
    with $FutureModifier<ReportData>, $FutureProvider<ReportData> {
  ReportDataProvider._({
    required ReportDataFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'reportDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reportDataHash();

  @override
  String toString() {
    return r'reportDataProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ReportData> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ReportData> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return reportData(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ReportDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reportDataHash() => r'6db326404671f04551c463a26de4eb0237313beb';

final class ReportDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReportData>, (DateTime, DateTime)> {
  ReportDataFamily._()
    : super(
        retry: null,
        name: r'reportDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReportDataProvider call(DateTime start, DateTime endExclusive) =>
      ReportDataProvider._(argument: (start, endExclusive), from: this);

  @override
  String toString() => r'reportDataProvider';
}

@ProviderFor(reportBusinessSettings)
final reportBusinessSettingsProvider = ReportBusinessSettingsProvider._();

final class ReportBusinessSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<BusinessSettings>,
          BusinessSettings,
          FutureOr<BusinessSettings>
        >
    with $FutureModifier<BusinessSettings>, $FutureProvider<BusinessSettings> {
  ReportBusinessSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportBusinessSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportBusinessSettingsHash();

  @$internal
  @override
  $FutureProviderElement<BusinessSettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BusinessSettings> create(Ref ref) {
    return reportBusinessSettings(ref);
  }
}

String _$reportBusinessSettingsHash() =>
    r'26586dc73e6971defb58af67c0123d4a0cc65e44';
