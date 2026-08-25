import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_role.dart';

part 'user.freezed.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required UserRole role,
    required String name,
    required String username,
    String? email,
    required String passwordHash,
    String? phone,
    required String status,
  }) = _User;

  const User._();

  bool get isActive => status == 'active';
}
