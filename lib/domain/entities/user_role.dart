import '../../data/local/tables/roles_table.dart';

/// Mirrors PHP's 3 seeded roles (admin/manager/cashier). Mapped to/from
/// the fixed UUIDs in [RoleIds] so role-based logic reads as clean Dart
/// instead of raw UUID string comparisons everywhere.
enum UserRole {
  admin,
  manager,
  cashier;

  String get roleId => switch (this) {
        UserRole.admin => RoleIds.admin,
        UserRole.manager => RoleIds.manager,
        UserRole.cashier => RoleIds.cashier,
      };

  static UserRole fromRoleId(String roleId) => switch (roleId) {
        RoleIds.admin => UserRole.admin,
        RoleIds.manager => UserRole.manager,
        RoleIds.cashier => UserRole.cashier,
        _ => throw ArgumentError('Unknown roleId: $roleId'),
      };

  /// Matches PHP's per-route Auth::requireRole([...]) whitelist model:
  /// each permission lists exactly which roles may perform it.
  bool isAtLeast(Set<UserRole> allowed) => allowed.contains(this);
}

/// Whether [role] sees the shop's money: on the dashboard Sales Today, Net Profit Today, Stock Value and the Last 7 Days
/// chart, and Reports at all. Admins and managers do. A cashier does not: the dashboard shows only Low Stock, and there
/// is no Reports button and no way into Reports (the router sends a cashier back home). The owner, 2026-11-23: "make
/// the cashier user not to be able to see daily sales or profits on the dashboard or stock value", then "I want the
/// reports section completely removed from cashier user". (Reports also hides its totals from anyone this says no to,
/// should one ever get there.) A list of the roles that may, so a role added later sees nothing until it is put here.
bool canSeeShopFigures(UserRole role) => role.isAtLeast({UserRole.admin, UserRole.manager});
