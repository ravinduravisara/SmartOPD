import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/glass.dart';
import '../../widgets/loading.dart';
import '../auth/providers/auth_provider.dart';
import 'data/catalog_models.dart';
import 'data/catalog_service.dart';
import 'data/user_management_models.dart';
import 'data/user_management_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({required this.auth, super.key});
  final AuthProvider auth;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final AdminUserManagementService _service =
      AdminUserManagementService(widget.auth.service.api);
  late final AdminCatalogService _catalog =
      AdminCatalogService(widget.auth.service.api);
  final _search = TextEditingController();
  Timer? _searchDebounce;
  UserPage? _page;
  String _role = 'all';
  String _verified = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.users(
        query: _search.text,
        role: _role,
        verified: _verified,
        page: page,
      );
      if (mounted) setState(() => _page = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(),
    );
  }

  Future<void> _edit([AdminUser? user]) async {
    final hospitals = await _catalog.hospitals();
    final departments = await _catalog.departments();
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _UserForm(
        service: _service,
        user: user,
        hospitals: hospitals,
        departments: departments,
      ),
    );
    if (changed == true) _load(page: _page?.page ?? 1);
  }

  Future<void> _delete(AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('This permanently removes ${user.name} and their login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted')));
        _load(page: _page?.page ?? 1);
      }

    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _createDoctorAccount(AdminUser user) async {
    final doctorId = user.doctorProfile?['id']?.toString();
    if (doctorId == null || doctorId.isEmpty) return;
    final email = TextEditingController();
    final password = TextEditingController();
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create login for ${user.name}'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Login email'),
                validator: (value) => value == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value.trim())
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary password',
                  helperText: 'At least 8 characters',
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      email.dispose();
      password.dispose();
      return;
    }
    try {
      await _service.createDoctorAccount(
        doctorId: doctorId,
        email: email.text,
        password: password.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor login account created')),
        );
        _load(page: _page?.page ?? 1);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      email.dispose();
      password.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Users & administrators', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Search, filter and manage every SmartOPD account.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Padding(padding: EdgeInsets.all(12), child: Text('Create user')),
      ),
      const SizedBox(height: 18),
      GlassSurface(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _search,
              onChanged: _searchChanged,
              decoration: const InputDecoration(
                hintText: 'Search name, email or phone',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.tune),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _filter('Role', _role, ['all', 'patient', 'doctor', 'admin'], (value) { setState(() => _role = value!); _load(); })),
                const SizedBox(width: 10),
                Expanded(child: _filter('Verification', _verified, ['all', 'true', 'false'], (value) { setState(() => _verified = value!); _load(); })),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      if (_loading)
        const LoadingView(padding: 24)
      else if (_error != null)
        ErrorView(message: _error!, onRetry: _load)
      else if (_page != null) ...[
        Text('${_page!.total} users', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (_page!.users.isEmpty)
          const GlassSurface(child: Center(child: Padding(padding: EdgeInsets.all(28), child: Text('No users match these filters.'))))
        else
          for (final user in _page!.users) _userCard(user),
        if (_page!.pages > 1) _pagination(),
      ],
    ],
  );

  Widget _filter(String label, String value, List<String> values, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
    items: values.map((item) => DropdownMenuItem(value: item, child: Text(_label(item)))).toList(),
    onChanged: onChanged,
  );

  String _label(String value) => switch (value) {
    'all' => 'All',
    'true' => 'Verified',
    'false' => 'Unverified',
    _ => '${value[0].toUpperCase()}${value.substring(1)}',
  };

  Widget _userCard(AdminUser user) => GlassSurface(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.teal.withValues(alpha: 0.14),
        child: Icon(user.role == 'admin' ? Icons.shield_outlined : Icons.person_outline, color: AppTheme.teal),
      ),
      title: Text(user.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        '${user.catalogOnly ? 'No login account' : user.email}'
        '${user.phone == null || user.phone!.isEmpty ? '' : '\n${user.phone}'}'
        '${user.catalogOnly ? '\nDoctor catalog profile — create a user account to enable login' : user.role == 'doctor' && user.doctorProfile == null ? '\nDoctor profile not configured — edit to assign hospital and department' : ''}',
        style: user.catalogOnly || user.role == 'doctor' && user.doctorProfile == null
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      isThreeLine: user.phone != null && user.phone!.isNotEmpty,
      trailing: user.catalogOnly
          ? TextButton.icon(
              onPressed: () => _createDoctorAccount(user),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Create login'),
            )
          : PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? _edit(user) : _delete(user),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit user')),
          PopupMenuItem(value: 'delete', child: Text('Delete user')),
        ],
      ),
    ),
  );

  Widget _pagination() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(onPressed: _page!.page > 1 ? () => _load(page: _page!.page - 1) : null, icon: const Icon(Icons.chevron_left)),
      Text('${_page!.page} / ${_page!.pages}'),
      IconButton(onPressed: _page!.page < _page!.pages ? () => _load(page: _page!.page + 1) : null, icon: const Icon(Icons.chevron_right)),
    ],
  );
}

class _UserForm extends StatefulWidget {
  const _UserForm({
    required this.service,
    required this.hospitals,
    required this.departments,
    this.user,
  });
  final AdminUserManagementService service;
  final AdminUser? user;
  final List<AdminHospital> hospitals;
  final List<AdminDepartment> departments;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);
  late final _phone = TextEditingController(text: widget.user?.phone);
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'patient';
  late final _specialization = TextEditingController(
    text: widget.user?.doctorProfile?['specialization'] as String?,
  );
  String? _hospitalId;
  String? _departmentId;
  bool _verified = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.user?.doctorProfile;
    final hospital = profile?['hospital'];
    final department = profile?['department'];
    _hospitalId = hospital is Map ? hospital['_id']?.toString() : hospital?.toString();
    _departmentId = department is Map ? department['_id']?.toString() : department?.toString();
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _phone.dispose(); _password.dispose(); _specialization.dispose(); super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await widget.service.save(
        id: widget.user?.id,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        role: _role,
        password: _password.text,
        isEmailVerified: widget.user == null ? _verified : null,
        specialization: _specialization.text,
        hospitalId: _hospitalId,
        departmentId: _departmentId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.user == null ? 'Create user' : 'Edit user'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(controller: _name, enabled: !_saving, decoration: const InputDecoration(labelText: 'Full name'), validator: (value) => value == null || value.trim().isEmpty ? 'Enter a name' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _email, enabled: !_saving, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address'), validator: (value) => value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? 'Enter a valid email' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _phone, enabled: !_saving, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(initialValue: _role, decoration: const InputDecoration(labelText: 'Role'), items: const [
                DropdownMenuItem(value: 'patient', child: Text('Patient')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
              ], onChanged: _saving ? null : (value) => setState(() => _role = value!)),
              if (_role == 'doctor') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _specialization,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Specialization'),
                  validator: (value) => _role == 'doctor' && (value == null || value.trim().isEmpty)
                      ? 'Enter a specialization'
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _hospitalId,
                  decoration: const InputDecoration(labelText: 'Hospital'),
                  items: widget.hospitals.map((hospital) => DropdownMenuItem(
                    value: hospital.id,
                    child: Text(hospital.name),
                  )).toList(),
                  onChanged: _saving ? null : (value) => setState(() {
                    _hospitalId = value;
                    _departmentId = null;
                  }),
                  validator: (value) => value == null ? 'Select a hospital' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _departmentId,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: widget.departments
                      .where((department) => _hospitalId == null || department.hospital.id == _hospitalId)
                      .map((department) => DropdownMenuItem(
                        value: department.id,
                        child: Text(department.name),
                      )).toList(),
                  onChanged: _saving ? null : (value) => setState(() => _departmentId = value),
                  validator: (value) => value == null ? 'Select a department' : null,
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(controller: _password, enabled: !_saving, obscureText: true, decoration: InputDecoration(labelText: widget.user == null ? 'Temporary password' : 'New password (optional)'), validator: (value) => widget.user == null && (value == null || value.length < 8) ? 'Use at least 8 characters' : null),
              if (widget.user == null) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Email verified'), value: _verified, onChanged: _saving ? null : (value) => setState(() => _verified = value)),
              if (_error != null) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
    ],
  );
}
