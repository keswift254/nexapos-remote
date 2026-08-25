import 'package:intl/intl.dart';

/// Exact monetary value stored as integer minor units (cents).
///
/// SQLite has no native DECIMAL type - REAL is IEEE-754 float and will
/// eventually drift on totals. All arithmetic here is integer-only; the
/// only place a double is allowed to appear is [fromMajor] (parsing a
/// human-entered amount like a price field) and [toMajorDouble]/[format]
/// (display).
class Money implements Comparable<Money> {
  final int cents;

  const Money(this.cents);

  const Money.zero() : cents = 0;

  factory Money.fromMajor(num major) => Money((major * 100).round());

  double get toMajorDouble => cents / 100;

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  Money operator *(int factor) => Money(cents * factor);

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool get isNegative => cents < 0;

  bool get isZero => cents == 0;

  /// Clamps this value so it never goes below zero, e.g. for a discount
  /// that must not exceed the subtotal.
  Money clampMin(Money min) => cents < min.cents ? min : this;

  String format({String currency = 'KES', String locale = 'en_KE'}) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: '$currency ',
      decimalDigits: 2,
    );
    return formatter.format(toMajorDouble);
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => format();
}
