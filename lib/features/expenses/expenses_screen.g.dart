// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expenses_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(expensesForDate)
final expensesForDateProvider = ExpensesForDateFamily._();

final class ExpensesForDateProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          FutureOr<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $FutureProvider<List<Expense>> {
  ExpensesForDateProvider._({
    required ExpensesForDateFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'expensesForDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expensesForDateHash();

  @override
  String toString() {
    return r'expensesForDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Expense>> create(Ref ref) {
    final argument = this.argument as DateTime;
    return expensesForDate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpensesForDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expensesForDateHash() => r'689f9600517e8fd948d9990908e69b296f7adde8';

final class ExpensesForDateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Expense>>, DateTime> {
  ExpensesForDateFamily._()
    : super(
        retry: null,
        name: r'expensesForDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExpensesForDateProvider call(DateTime date) =>
      ExpensesForDateProvider._(argument: date, from: this);

  @override
  String toString() => r'expensesForDateProvider';
}

@ProviderFor(expenseEnteredByName)
final expenseEnteredByNameProvider = ExpenseEnteredByNameFamily._();

final class ExpenseEnteredByNameProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  ExpenseEnteredByNameProvider._({
    required ExpenseEnteredByNameFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'expenseEnteredByNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expenseEnteredByNameHash();

  @override
  String toString() {
    return r'expenseEnteredByNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String?;
    return expenseEnteredByName(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseEnteredByNameProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expenseEnteredByNameHash() =>
    r'df339e1f0851070a52a1cfbd36d0db8b3fcd60d9';

final class ExpenseEnteredByNameFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String?> {
  ExpenseEnteredByNameFamily._()
    : super(
        retry: null,
        name: r'expenseEnteredByNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExpenseEnteredByNameProvider call(String? userId) =>
      ExpenseEnteredByNameProvider._(argument: userId, from: this);

  @override
  String toString() => r'expenseEnteredByNameProvider';
}
