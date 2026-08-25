import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/user.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/session_service.dart';
import 'user_form_sheet.dart';

part 'users_screen.g.dart';

@riverpod
Future<List<User>> allUsers(Ref ref) {
  return ref.watch(authServiceProvider).getAllUsers();
}

/// Admin-only (enforced by the router redirect, not just by not linking
/// here) port of PHP's Users & Roles page: save_user/update_user.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, {User? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => UserFormSheet(existing: existing),
    );
    ref.invalidate(allUsersProvider);
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref, User user) async {
    final currentUserId = ref.read(sessionProvider)?.id ?? '';
    final result = await ref
        .read(authServiceProvider)
        .setUserActive(user.id, active: !user.isActive, currentUserId: currentUserId);
    result.when(
      ok: (_) => ref.invalidate(allUsersProvider),
      failure: (message) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Users & Roles')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load users: $error')),
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              title: Text(user.name),
              subtitle: Text('${user.username} · ${user.role.name}'),
              trailing: Switch(
                value: user.isActive,
                onChanged: (_) => _toggleActive(context, ref, user),
              ),
              onTap: () => _openForm(context, ref, existing: user),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
    );
  }
}
