import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../auth/providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.auth, super.key});
  final AuthProvider auth;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<User> _admins = [];
  bool _loading = true;
  bool _creating = false;
  bool _saving = false;
  bool _obscure = true;
  String? _error;
  String? _formError;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.auth.service.api.request(
        'GET',
        '/admin/dashboard',
      );
      if (!mounted) return;
      setState(
        () => _admins = (data['admins'] as List)
            .map((item) => User.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await widget.auth.service.api.request(
        'POST',
        '/admin/admins',
        body: {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text,
        },
      );
      if (!mounted) return;
      _clearForm();
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin created. They can now use the same login screen.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _formError = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    _name.clear();
    _email.clear();
    _password.clear();
    _confirm.clear();
    _formError = null;
    _obscure = true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.user?.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Administrator access required')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.auth.loading || _saving
                ? null
                : () => widget.auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.teal,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.admin_panel_settings_outlined,
                              color: AppTheme.mint,
                              size: 36,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'ADMINISTRATION',
                              style: TextStyle(
                                color: AppTheme.mint,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Welcome, ${widget.auth.user!.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Manage administrator access to SmartOPD.',
                              style: TextStyle(
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _creating
                            ? null
                            : () => setState(() => _creating = true),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('Create new admin'),
                        ),
                      ),
                      if (_creating) ...[
                        const SizedBox(height: 20),
                        _createForm(),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Administrators',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'These accounts can access this dashboard and create admins.',
                      ),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Text(_error!),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          '${_admins.length} administrator${_admins.length == 1 ? '' : 's'}',
                        ),
                        const SizedBox(height: 12),
                        for (final admin in _admins)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.shield_outlined),
                                ),
                                title: Text(admin.name),
                                subtitle: Text(admin.email),
                                trailing: admin.id == widget.auth.user!.id
                                    ? const Text('You')
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createForm() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New administrator',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create an account for an authorized team member. Share their password privately.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) =>
                  value == null ||
                      value.trim().length > 254 ||
                      !RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value.trim())
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              enabled: !_saving,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText:
                    '8–128 characters: uppercase, lowercase, number and symbol',
                helperMaxLines: 3,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  value == null ||
                      value.length < 8 ||
                      value.length > 128 ||
                      !RegExp(r'[A-Z]').hasMatch(value) ||
                      !RegExp(r'[a-z]').hasMatch(value) ||
                      !RegExp(r'\d').hasMatch(value) ||
                      !RegExp(r'[^A-Za-z0-9]').hasMatch(value)
                  ? 'Use the password requirements above'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              enabled: !_saving,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match' : null,
            ),
            if (_formError != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _formError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _create,
              child: Text(_saving ? 'Creating admin…' : 'Create admin'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      _clearForm();
                      setState(() => _creating = false);
                    },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
