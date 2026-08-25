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
