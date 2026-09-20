import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/glass.dart';
import '../../widgets/loading.dart';
import '../auth/providers/auth_provider.dart';
import 'catalog/departments_tab.dart';
import 'catalog/doctors_tab.dart';
import 'catalog/hospitals_tab.dart';
import 'data/catalog_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.auth, super.key});
  final AuthProvider auth;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  /// The catalog the booking flow reads: cities, hospitals, departments and
  /// doctors. It shares the signed-in admin's client, so it carries the token.
  late final AdminCatalogService _catalog = AdminCatalogService(
    widget.auth.service.api,
  );

  /// Status hues that have to stay apart from each other and from the teal.
  static const _flow = Color(0xFF438AF0);
  static const _good = Color(0xFF10AD7C);
  static const _bad = Color(0xFFEF6D83);

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
      return const GlassScaffold(
        appBar: false,
        body: Center(child: Text('Administrator access required')),
      );
    }
    return GlassScaffold(
      titleWidget: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SmartOPD Portal',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Hospital administration',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
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
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.teal, AppTheme.navy],
              ),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottomNavigationBar: _navigation(),
      body: RefreshIndicator(
        onRefresh: _load,
        // Keeps the spinner clear of the translucent app bar.
        edgeOffset: glassTopInset(context),
        color: AppTheme.teal,
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            18 + glassTopInset(context),
            18,
            110,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _tabBody(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Catalog tabs opened at least once. They stay in the tree behind an
  /// [Offstage] so returning to one shows the rows it already loaded, instead
  /// of tearing the state down and refetching behind a spinner every time.
  final _opened = <int>{};

  List<Widget> _tabBody() => [
    if (_tab == 0) ..._overview(),
    if (_tab == 4) ..._administrators(),
    if (_opened.contains(1))
      Offstage(
        offstage: _tab != 1,
        child: HospitalsAdminTab(service: _catalog),
      ),
    if (_opened.contains(2))
      Offstage(
        offstage: _tab != 2,
        child: DepartmentsAdminTab(service: _catalog),
      ),
    if (_opened.contains(3))
      Offstage(
        offstage: _tab != 3,
        child: DoctorsAdminTab(service: _catalog),
      ),
  ];

  /// Translucent bottom bar. It deliberately does NOT blur: this screen
  /// already blurs its app bar, and content scrolling under two blurred bars
  /// re-ran both full-width blurs every frame, which is what made the admin
  /// screens heavier than the rest of the app.
  Widget _navigation() => ClipRect(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          // Opaque enough to read against scrolling content now that the
          // bar no longer frosts what passes behind it.
          backgroundColor: const Color(0xF0FFFFFF),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppTheme.teal.withValues(alpha: 0.16),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? AppTheme.teal
                  : AppTheme.textMuted,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppTheme.teal
                  : AppTheme.textMuted,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _saving
              ? null
              : (index) => setState(() {
                  _tab = index;
                  if (index > 0 && index < 4) _opened.add(index);
                }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              label: 'Hospitals',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              label: 'Depts',
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
      ),
    ),
  );

  /// Tinted square holding an icon — the pattern every status colour uses.
  Widget _iconChip(IconData icon, Color color, {double size = 38}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(size / 2.8),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Icon(icon, color: color, size: size * 0.52),
  );

  List<Widget> _overview() => [
    const GlassHeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, Administrator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'General operations at a glance',
            style: TextStyle(color: Color(0xCCD9F2EE), fontSize: 12.5),
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    const Text(
      'DASHBOARD PREVIEW ? SAMPLE DATA',
      style: TextStyle(
        fontSize: 10,
        color: AppTheme.textMuted,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
      ),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: _metric(
            '342',
            "Today's patients",
            _flow,
            Icons.groups_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric(
            '67',
            'Waiting',
            AppTheme.navy,
            Icons.hourglass_bottom_rounded,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: _metric(
            '245',
            'Completed',
            _good,
            Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric('18', 'No-shows', _bad, Icons.event_busy_outlined),
        ),
      ],
    ),
    const SizedBox(height: 16),
    GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Flow Today',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Hourly arrivals & consultations',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
                            width: 26,
                            height: [38.0, 57.0, 90.0, 71.0, 104.0, 123.0][i],
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.teal.withValues(alpha: 0.85),
                                  AppTheme.mint.withValues(alpha: 0.55),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppTheme.glassBorder),
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
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
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
    GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _status('Active Queue Monitor', 'Normal (18m wait)', _good),
          const Divider(height: 24, color: AppTheme.glassBorder, thickness: 1),
          _status('On-Duty Doctors', '31 of 42 available', AppTheme.navy),
        ],
      ),
    ),
  ];

  Widget _metric(String value, String label, Color color, IconData icon) =>
      GlassSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconChip(icon, color, size: 34),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _status(String label, String value, Color color) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ],
  );

  List<Widget> _administrators() => [
    Text('Administrators', style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 8),
    Text(
      'Manage access to the SmartOPD admin portal.',
      style: Theme.of(context).textTheme.bodyMedium,
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
      const LoadingView(padding: 24)
    else if (_error != null)
      ErrorView(message: _error!, onRetry: _load)
    else ...[
      Text(
        '${_admins.length} administrators',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      for (final admin in _admins)
        GlassSurface(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _iconChip(Icons.shield_outlined, AppTheme.teal, size: 42),
            title: Text(
              admin.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              admin.email,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing: admin.id == widget.auth.user!.id
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.teal.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: AppTheme.teal,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
        ),
    ],
  ];

  Widget _createForm() => GlassSurface(
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
          Text(
            'Create an account for an authorized team member. Share their password privately.',
            style: Theme.of(context).textTheme.bodyMedium,
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
  );
}
