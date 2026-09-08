import 'package:flutter/material.dart';

import 'config/theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'models/dependent.dart';

void main() => runApp(const SmartOpdApp());

class SmartOpdApp extends StatefulWidget {
  const SmartOpdApp({super.key});

  @override
  State<SmartOpdApp> createState() => _SmartOpdAppState();
}

class _SmartOpdAppState extends State<SmartOpdApp> {
  final auth = AuthProvider();

  @override
  void initState() {
    super.initState();
    auth.restoreSession().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartOPD',
    theme: AppTheme.light,
    home: auth.user == null
        ? AuthScreen(auth: auth, onChanged: () => setState(() {}))
        : HomeScreen(auth: auth, onChanged: () => setState(() {})),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.auth, required this.onChanged, super.key});
  final AuthProvider auth;
  final VoidCallback onChanged;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandLockup(),
                const SizedBox(height: 52),
                Text(
                  register ? 'Create your account' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  register
                      ? 'Your care journey starts here.'
                      : 'Manage your appointments and family care in one place.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                if (register) ...[
                  _field('Full name', name, Icons.person_outline),
                  const SizedBox(height: 14),
                ],
                _field(
                  'Email address',
                  email,
                  Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (!register)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showMessage(
                        'Password reset is available from the API.',
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: widget.auth.loading ? null : _submit,
                    child: widget.auth.loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(register ? 'Create account' : 'Log in'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => register = !register),
                    child: Text(
                      register
                          ? 'Already have an account? Log in'
                          : 'New to SmartOPD? Create an account',
                    ),
                  ),
                ),
                if (widget.auth.error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorMessage(message: widget.auth.error!),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );

  Future<void> _submit() async {
    if (register) {
      await widget.auth.register(
        name.text.trim(),
        email.text.trim(),
        password.text,
      );
    } else {
      await widget.auth.login(email.text.trim(), password.text);
    }
    if (mounted && widget.auth.user != null) widget.onChanged();
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.auth, required this.onChanged, super.key});
  final AuthProvider auth;
  final VoidCallback onChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Dependent>> dependents;
  final dependentName = TextEditingController();
  final dependentRelationship = TextEditingController();
  final editDependentName = TextEditingController();
  final editDependentRelationship = TextEditingController();
  late final TextEditingController profileName;
  bool addingDependent = false;
  bool savingDependent = false;
  bool savingDependentEdit = false;
  String? editingDependentId;
  String? deletingDependentId;
  bool editingProfile = false;
  bool savingProfile = false;

  @override
  void initState() {
    super.initState();
    dependents = widget.auth.service.getDependents();
    profileName = TextEditingController(text: widget.auth.user?.name);
  }

  @override
  void dispose() {
    dependentName.dispose();
    dependentRelationship.dispose();
    editDependentName.dispose();
    editDependentRelationship.dispose();
    profileName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const _BrandLockup(compact: true),
      actions: [
        IconButton(
          tooltip: 'Log out',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () async =>
          setState(() => dependents = widget.auth.service.getDependents()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Good morning,', style: Theme.of(context).textTheme.bodyLarge),
          Text(
            widget.auth.user?.name ?? 'there',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 22),
          const _CareCard(),
          const SizedBox(height: 28),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Book visit',
                  onTap: () =>
                      _showMessage('Choose a doctor to book an appointment.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Add family',
                  onTap: _openDependentForm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Family members',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                tooltip: 'Add family member',
                onPressed: _openDependentForm,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (addingDependent) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: dependentName,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dependentRelationship,
                      decoration: const InputDecoration(
                        labelText: 'Relationship',
                        prefixIcon: Icon(Icons.family_restroom_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: savingDependent
                                ? null
                                : () => setState(() => addingDependent = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: savingDependent ? null : _saveDependent,
                            child: savingDependent
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save member'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FutureBuilder<List<Dependent>>(
            future: dependents,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return _ErrorMessage(message: snapshot.error.toString());
              }
              final members = snapshot.data ?? const <Dependent>[];
              if (members.isEmpty) return const _EmptyDependents();
              return Column(children: members.map(_dependentTile).toList());
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _openProfileForm,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          if (editingProfile) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: profileName,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: savingProfile
                                ? null
                                : () => setState(() => editingProfile = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: savingProfile ? null : _saveProfile,
                            child: savingProfile
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _dependentTile(Dependent dependent) {
    if (editingDependentId == dependent.id) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: editDependentName,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editDependentRelationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.family_restroom_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: savingDependentEdit
                          ? null
                          : _cancelDependentEdit,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: savingDependentEdit
                          ? null
                          : () => _saveDependentEdit(dependent.id),
                      child: savingDependentEdit
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final initial = dependent.name.trim().isEmpty
        ? '?'
        : dependent.name.trim().substring(0, 1).toUpperCase();
    final deleting = deletingDependentId == dependent.id;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(initial)),
        title: Text(dependent.name),
        subtitle: Text(dependent.relationship),
        trailing: deleting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Edit ${dependent.name}',
                    onPressed: () => _openDependentEdit(dependent),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete ${dependent.name}',
                    onPressed: () => _deleteDependent(dependent),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (mounted) widget.onChanged();
  }

  void _openDependentForm() {
    setState(() => addingDependent = true);
  }

  void _openDependentEdit(Dependent dependent) {
    setState(() {
      editingDependentId = dependent.id;
      editDependentName.text = dependent.name;
      editDependentRelationship.text = dependent.relationship;
    });
  }

  void _cancelDependentEdit() {
    setState(() {
      editingDependentId = null;
      savingDependentEdit = false;
      editDependentName.clear();
      editDependentRelationship.clear();
    });
  }

  Future<void> _saveDependentEdit(String id) async {
    final name = editDependentName.text.trim();
    final relationship = editDependentRelationship.text.trim();
    if (name.isEmpty || relationship.isEmpty) {
      _showMessage('Enter a name and relationship first.');
      return;
    }

    setState(() => savingDependentEdit = true);
    try {
      await widget.auth.service.updateDependent(id, {
        'name': name,
        'relationship': relationship,
      });
      if (mounted) {
        setState(() {
          editingDependentId = null;
          savingDependentEdit = false;
          editDependentName.clear();
          editDependentRelationship.clear();
          dependents = widget.auth.service.getDependents();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => savingDependentEdit = false);
        _showMessage('Could not update member: $error');
      }
    }
  }

  Future<void> _deleteDependent(Dependent dependent) async {
    setState(() => deletingDependentId = dependent.id);
    try {
      await widget.auth.service.removeDependent(dependent.id);
      if (mounted) {
        setState(() {
          deletingDependentId = null;
          dependents = widget.auth.service.getDependents();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => deletingDependentId = null);
        _showMessage('Could not delete member: $error');
      }
    }
  }

  Future<void> _saveDependent() async {
    final name = dependentName.text.trim();
    final relationship = dependentRelationship.text.trim();
    if (name.isEmpty || relationship.isEmpty) {
      _showMessage('Enter a name and relationship first.');
      return;
    }

    setState(() => savingDependent = true);
    try {
      await widget.auth.service.addDependent(
        Dependent(
          id: '',
          name: name,
          relationship: relationship,
          dateOfBirth: DateTime(2000),
        ),
      );
      if (mounted) {
        setState(() {
          addingDependent = false;
          savingDependent = false;
          dependentName.clear();
          dependentRelationship.clear();
          dependents = widget.auth.service.getDependents();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => savingDependent = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add member: $error')));
      }
    }
  }

  void _openProfileForm() {
    profileName.text = widget.auth.user?.name ?? '';
    setState(() => editingProfile = true);
  }

  Future<void> _saveProfile() async {
    final name = profileName.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter your name first.');
      return;
    }

    setState(() => savingProfile = true);
    try {
      await widget.auth.service.updateProfile({'name': name});
      if (mounted)
        setState(() {
          editingProfile = false;
          savingProfile = false;
        });
    } catch (error) {
      if (mounted) {
        setState(() => savingProfile = false);
        _showMessage('Could not save profile: $error');
      }
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/hospital_management_system.png',
    width: compact ? 150 : 245,
    height: compact ? 44 : 112,
    fit: BoxFit.contain,
    alignment: Alignment.centerLeft,
    errorBuilder: (context, error, stackTrace) => Text(
      'SmartOPD',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _CareCard extends StatelessWidget {
  const _CareCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.navy,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your care, simplified',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your appointments and loved ones close.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(
          Icons.favorite_outline_rounded,
          color: AppTheme.mint,
          size: 42,
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.teal),
            const SizedBox(height: 18),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

class _EmptyDependents extends StatelessWidget {
  const _EmptyDependents();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.people_outline, color: AppTheme.teal, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Add a family member to book care for them.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SmartOPD',
    theme: AppTheme.light,
    home: const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('SmartOPD'), Text('SmartOPD is ready')],
        ),
      ),
    ),
  );
}
