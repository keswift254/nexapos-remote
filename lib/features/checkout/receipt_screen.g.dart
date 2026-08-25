// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(receiptData)
final receiptDataProvider = ReceiptDataFamily._();

final class ReceiptDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReceiptData>,
          ReceiptData,
          FutureOr<ReceiptData>
        >
    with $FutureModifier<ReceiptData>, $FutureProvider<ReceiptData> {
  ReceiptDataProvider._({
    required ReceiptDataFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'receiptDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$receiptDataHash();

  @override
  String toString() {
    return r'receiptDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReceiptData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReceiptData> create(Ref ref) {
    final argument = this.argument as String;
    return receiptData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReceiptDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$receiptDataHash() => r'99a2f91f2e5bebd48fd3190955cec529dfb7b7d2';

final class ReceiptDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReceiptData>, String> {
  ReceiptDataFamily._()
    : super(
        retry: null,
        name: r'receiptDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReceiptDataProvider call(String saleId) =>
      ReceiptDataProvider._(argument: saleId, from: this);

  @override
  String toString() => r'receiptDataProvider';
}
