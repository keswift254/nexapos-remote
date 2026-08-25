// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Deliberately narrower than the PHP dashboard's dashboardChartData:
/// today-vs-yesterday stats plus a 7-day trend, not its full daily/
/// weekly/monthly/yearly bucketed chart system (see ReportsService's
/// doc comment - that's a separate, heavier feature to add later if
/// wanted). Low-stock count and stock value mirror the PHP dashboard's
/// own SQL exactly (COUNT stock_qty<=reorder_level and
/// SUM(stock_qty*cost_price) across ALL products, no status filter) -
/// PHP computes a "change" for these two by comparing that same
/// point-in-time value to itself, which is always flat, so that part
/// is dropped rather than ported.
/// Fires on every write to any local table (inserts/updates/deletes, and
/// the raw-SQL stock_qty adjustment too - it declares `updates: {products}`)
/// regardless of which repository/service performed it. dashboardData
/// watches this so a sale, expense, or stock change anywhere in the app -
/// now or in any future code path - refreshes the dashboard on its own,
/// without every write site needing to remember to invalidate it.
/// keepAlive here (this used to be plain autodispose): a defensive
/// choice, not a distinctly-proven fix - a real report was "dashboard
/// doesn't update after a sale until I hit refresh," and this closes
/// the specific gap where autodispose would tear this subscription down
/// entirely while nothing was watching the dashboard (mid-sale, on the
/// cart/checkout/receipt screens), silently losing a write that
/// happened during that window. Belt-and-suspenders alongside this:
/// the actual sale-completion sites (cart_screen.dart,
/// paystack_waiting_screen.dart) now also call
/// `ref.invalidate(dashboardDataProvider)` explicitly right before
/// navigating back - THAT part is the unconditionally-correct fix,
/// verified for real; this keepAlive is the more theoretical half.

@ProviderFor(dashboardChangeTicker)
final dashboardChangeTickerProvider = DashboardChangeTickerProvider._();

/// Deliberately narrower than the PHP dashboard's dashboardChartData:
/// today-vs-yesterday stats plus a 7-day trend, not its full daily/
/// weekly/monthly/yearly bucketed chart system (see ReportsService's
/// doc comment - that's a separate, heavier feature to add later if
/// wanted). Low-stock count and stock value mirror the PHP dashboard's
/// own SQL exactly (COUNT stock_qty<=reorder_level and
/// SUM(stock_qty*cost_price) across ALL products, no status filter) -
/// PHP computes a "change" for these two by comparing that same
/// point-in-time value to itself, which is always flat, so that part
/// is dropped rather than ported.
/// Fires on every write to any local table (inserts/updates/deletes, and
/// the raw-SQL stock_qty adjustment too - it declares `updates: {products}`)
/// regardless of which repository/service performed it. dashboardData
/// watches this so a sale, expense, or stock change anywhere in the app -
/// now or in any future code path - refreshes the dashboard on its own,
/// without every write site needing to remember to invalidate it.
/// keepAlive here (this used to be plain autodispose): a defensive
/// choice, not a distinctly-proven fix - a real report was "dashboard
/// doesn't update after a sale until I hit refresh," and this closes
/// the specific gap where autodispose would tear this subscription down
/// entirely while nothing was watching the dashboard (mid-sale, on the
/// cart/checkout/receipt screens), silently losing a write that
/// happened during that window. Belt-and-suspenders alongside this:
/// the actual sale-completion sites (cart_screen.dart,
/// paystack_waiting_screen.dart) now also call
/// `ref.invalidate(dashboardDataProvider)` explicitly right before
/// navigating back - THAT part is the unconditionally-correct fix,
/// verified for real; this keepAlive is the more theoretical half.

final class DashboardChangeTickerProvider
    extends $FunctionalProvider<AsyncValue<void>, void, Stream<void>>
    with $FutureModifier<void>, $StreamProvider<void> {
  /// Deliberately narrower than the PHP dashboard's dashboardChartData:
  /// today-vs-yesterday stats plus a 7-day trend, not its full daily/
  /// weekly/monthly/yearly bucketed chart system (see ReportsService's
  /// doc comment - that's a separate, heavier feature to add later if
  /// wanted). Low-stock count and stock value mirror the PHP dashboard's
  /// own SQL exactly (COUNT stock_qty<=reorder_level and
  /// SUM(stock_qty*cost_price) across ALL products, no status filter) -
  /// PHP computes a "change" for these two by comparing that same
  /// point-in-time value to itself, which is always flat, so that part
  /// is dropped rather than ported.
  /// Fires on every write to any local table (inserts/updates/deletes, and
  /// the raw-SQL stock_qty adjustment too - it declares `updates: {products}`)
  /// regardless of which repository/service performed it. dashboardData
  /// watches this so a sale, expense, or stock change anywhere in the app -
  /// now or in any future code path - refreshes the dashboard on its own,
  /// without every write site needing to remember to invalidate it.
  /// keepAlive here (this used to be plain autodispose): a defensive
  /// choice, not a distinctly-proven fix - a real report was "dashboard
  /// doesn't update after a sale until I hit refresh," and this closes
  /// the specific gap where autodispose would tear this subscription down
  /// entirely while nothing was watching the dashboard (mid-sale, on the
  /// cart/checkout/receipt screens), silently losing a write that
  /// happened during that window. Belt-and-suspenders alongside this:
  /// the actual sale-completion sites (cart_screen.dart,
  /// paystack_waiting_screen.dart) now also call
  /// `ref.invalidate(dashboardDataProvider)` explicitly right before
  /// navigating back - THAT part is the unconditionally-correct fix,
  /// verified for real; this keepAlive is the more theoretical half.
  DashboardChangeTickerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardChangeTickerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardChangeTickerHash();

  @$internal
  @override
  $StreamProviderElement<void> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<void> create(Ref ref) {
    return dashboardChangeTicker(ref);
  }
}

String _$dashboardChangeTickerHash() =>
    r'51c2d33f7e12bdd5167ac93443872f9187ae2081';

@ProviderFor(dashboardData)
final dashboardDataProvider = DashboardDataProvider._();

final class DashboardDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<DashboardData>,
          DashboardData,
          FutureOr<DashboardData>
        >
    with $FutureModifier<DashboardData>, $FutureProvider<DashboardData> {
  DashboardDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dashboardDataProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dashboardDataHash();

  @$internal
  @override
  $FutureProviderElement<DashboardData> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DashboardData> create(Ref ref) {
    return dashboardData(ref);
  }
}

String _$dashboardDataHash() => r'65aff3c60a5945d41f1a7093f6fb677e40a77228';
