import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/services/auth_service.dart';

/// Shared add/edit form for the Users & Roles screen. In edit mode the
/// password field is optional (blank keeps the existing hash) - in add
/// mode it's required, mirroring how PHP's save_user vs update_user
/// routes treat the password field differently.
class UserFormSheet extends ConsumerStatefulWidget {
  final User? existing;

  const UserFormSheet({super.key, this.existing});

  @override
  ConsumerState<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _usernameController = TextEditingController(text: widget.existing?.username);
  late final _emailController = TextEditingController(text: widget.existing?.email);
  late final _phoneController = TextEditingController(text: widget.existing?.phone);
  final _passwordController = TextEditingController();
  late UserRole _role = widget.existing?.role ?? UserRole.cashier;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    final result = _isEdit
        ? await auth.updateUser(
            id: widget.existing!.id,
            name: _nameController.text,
            username: _usernameController.text,
            role: _role,
            email: _emailController.text,
            phone: _phoneController.text,
            newPassword: _passwordController.text.isEmpty ? null : _passwordController.text,
          )
        : await auth.createUser(
            name: _nameController.text,
            username: _usernameController.text,
            password: _passwordController.text,
            role: _role,
            email: _emailController.text,
            phone: _phoneController.text,
          );

    result.when(
      ok: (_) {
        if (mounted) Navigator.of(context).pop();
      },
      failure: (message) => setState(() {
        _submitting = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Edit user' : 'Add user', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                    .toList(),
                onChanged: (r) => setState(() => _role = r ?? _role),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'New password (leave blank to keep current)' : 'Password',
                ),
                obscureText: true,
                validator: (v) {
                  if (_isEdit) return null;
                  return (v == null || v.length < 6) ? 'At least 6 characters' : null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEdit ? 'Save changes' : 'Create user'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
