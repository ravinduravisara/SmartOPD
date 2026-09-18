import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../auth/providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.auth, super.key});
  final AuthProvider auth;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;
  static const _navy = Color(0xFF102F4F);
  static const _muted = Color(0xFF7C8DA5);
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
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _navy),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _navy,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SmartOPD Portal',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text(
                'Hospital administration',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Administrator account',
              onSelected: (value) {
                if (value == 'logout') {
                  widget.auth.logout();
                } else {
                  setState(() => _tab = 4);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'admins',
                  child: Text('Manage administrators'),
                ),
                PopupMenuItem(
                  value: 'logout',
                  enabled: !_saving && !widget.auth.loading,
                  child: const Text('Log out'),
                ),
              ],
              icon: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF215780),
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _saving
              ? null
              : (index) => setState(() => _tab = index),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE7F0FF),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Appts',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted),
              label: 'Queue',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Doctors',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              label: 'More',
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _tab == 0
                          ? _overview()
                          : _tab == 4
                          ? _administrators()
                          : [
                              _panel(
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.construction_outlined,
                                      size: 36,
                                      color: _muted,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      [
                                        '',
                                        'Appointments',
                                        'Queue management',
                                        'Doctors',
                                      ][_tab],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: _navy,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'This admin section will be added in the next stage.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE1E8F0)),
    ),
    child: child,
  );

  List<Widget> _overview() => [
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, Administrator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'General operations at a glance',
            style: TextStyle(color: Color(0xFFCCD9E8), fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'DASHBOARD PREVIEW ? SAMPLE DATA',
      style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 1),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: _metric('342', "Today's patients", const Color(0xFF438AF0)),
        ),
        const SizedBox(width: 12),
        Expanded(child: _metric('67', 'Waiting', _navy)),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(child: _metric('245', 'Completed', const Color(0xFF10AD7C))),
        const SizedBox(width: 12),
        Expanded(child: _metric('18', 'No-shows', const Color(0xFFEF6D83))),
      ],
    ),
    const SizedBox(height: 16),
    _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Flow Today',
            style: TextStyle(
              color: _navy,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hourly arrivals & consultations',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 20),
          Semantics(
            label:
                'Sample hourly patient flow: 8 AM 18, 9 AM 27, 10 AM 43, 11 AM 34, noon 50, 1 PM 59.',
            child: SizedBox(
              height: 155,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 24,
                            height: [38.0, 57.0, 90.0, 71.0, 104.0, 123.0][i],
                            decoration: BoxDecoration(
                              color: const Color(0xFFBFDCF9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            [
                              '8:00',
                              '9:00',
                              '10:00',
                              '11:00',
                              '12:00',
                              '13:00',
                            ][i],
                            style: const TextStyle(fontSize: 10, color: _muted),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Status',
            style: TextStyle(
              color: _navy,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          _status(
            'Active Queue Monitor',
            'Normal (18m wait)',
            const Color(0xFF17A576),
          ),
          const Divider(height: 24, color: Color(0xFFEDF1F6)),
          _status('On-Duty Doctors', '31 of 42 available', _navy),
        ],
      ),
    ),
  ];

  Widget _metric(String value, String label, Color color) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );

  Widget _status(String label, String value, Color color) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  List<Widget> _administrators() => [
    const Text(
      'Administrators',
      style: TextStyle(color: _navy, fontSize: 24, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    const Text(
      'Manage access to the SmartOPD admin portal.',
      style: TextStyle(color: _muted),
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: _creating ? null : () => setState(() => _creating = true),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Padding(
        padding: EdgeInsets.all(14),
        child: Text('Create new admin'),
      ),
    ),
    if (_creating) ...[const SizedBox(height: 20), _createForm()],
    const SizedBox(height: 20),
    if (_loading)
      const Center(child: CircularProgressIndicator())
    else if (_error != null)
      _panel(
        Column(
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      )
    else ...[
      Text(
        '${_admins.length} administrators',
        style: const TextStyle(color: _muted),
      ),
      const SizedBox(height: 12),
      for (final admin in _admins)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _panel(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
              title: Text(admin.name),
              subtitle: Text(admin.email),
              trailing: admin.id == widget.auth.user!.id
                  ? const Text('You')
                  : null,
            ),
          ),
        ),
    ],
  ];

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
