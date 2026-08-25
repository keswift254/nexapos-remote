// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(expenseService)
final expenseServiceProvider = ExpenseServiceProvider._();

final class ExpenseServiceProvider
    extends $FunctionalProvider<ExpenseService, ExpenseService, ExpenseService>
    with $Provider<ExpenseService> {
  ExpenseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseServiceHash();

  @$internal
  @override
  $ProviderElement<ExpenseService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExpenseService create(Ref ref) {
    return expenseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExpenseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExpenseService>(value),
    );
  }
}

String _$expenseServiceHash() => r'5da1ffd23296bfe88395be83de6492d1b0d03649';
