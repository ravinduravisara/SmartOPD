import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'config/theme.dart';
import 'features/appointments/appointments_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/hospitals/hospitals_screen.dart';
import 'models/appointment.dart';
import 'models/dependent.dart';
import 'models/user.dart';
import 'utils/date_utils.dart';
import 'widgets/error_widget.dart';

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
    // Without this the provider's `loading` and `error` never reach the UI, so
    // a failed sign-in looks like the button simply did nothing.
    home: ListenableBuilder(
      listenable: auth,
      builder: (context, _) => auth.user == null
          ? AuthScreen(auth: auth, onChanged: () => setState(() {}))
          : HomeScreen(auth: auth, onChanged: () => setState(() {})),
    ),
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
  final otp = TextEditingController();
  final resetPassword = TextEditingController();
  bool register = false;
  bool obscurePassword = true;
  bool verificationStep = false;
  bool resetStep = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    otp.dispose();
    resetPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: verificationStep
          ? _verificationView(context)
          : Center(
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
                            onPressed: () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
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
                            onPressed: _startPasswordReset,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(register ? 'Create account' : 'Log in'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: widget.auth.loading
                              ? null
                              : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
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
    final emailValue = email.text.trim();
    if (!_isValidEmail(emailValue)) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (password.text.isEmpty) {
      _showMessage('Enter your password.');
      return;
    }
    if (register) {
      if (name.text.trim().isEmpty) {
        _showMessage('Enter your full name.');
        return;
      }
      if (!_isStrongPassword(password.text)) {
        _showMessage(
          'Use 8+ characters with uppercase, lowercase, number and symbol.',
        );
        return;
      }
      await widget.auth.register(name.text.trim(), emailValue, password.text);
      if (mounted && widget.auth.error == null) {
        setState(() => verificationStep = true);
      }
    } else {
      await widget.auth.login(emailValue, password.text);
    }
    if (mounted && widget.auth.user != null) widget.onChanged();
  }

  Future<void> _startPasswordReset() async {
    final emailValue = email.text.trim();
    if (!_isValidEmail(emailValue)) {
      _showMessage('Enter your email address first.');
      return;
    }
    await widget.auth.forgotPassword(emailValue);
    if (mounted && widget.auth.error == null) {
      setState(() {
        verificationStep = true;
        resetStep = true;
      });
      _showMessage('A password reset code was sent to your email.');
    }
  }

  Future<void> _signInWithGoogle() async {
    await widget.auth.signInWithGoogle();
    if (mounted && widget.auth.user != null) widget.onChanged();
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);

  bool _isStrongPassword(String value) =>
      value.length >= 8 &&
      value.length <= 128 &&
      RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[a-z]').hasMatch(value) &&
      RegExp(r'\d').hasMatch(value) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  Widget _verificationView(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _BrandLockup(),
            const SizedBox(height: 40),
            Text(
              resetStep ? 'Reset your password' : 'Verify your email',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              resetStep
                  ? 'Enter the code sent to ${email.text} and choose a new password.'
                  : 'Enter the 6-digit code sent to ${email.text}.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            if (resetStep) ...[
              const SizedBox(height: 12),
              TextField(
                controller: resetPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                  helperText:
                      '8+ chars with uppercase, lowercase, number and symbol',
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: widget.auth.loading ? null : _submitCode,
                child: Text(resetStep ? 'Reset password' : 'Verify email'),
              ),
            ),
            TextButton(
              onPressed: widget.auth.loading ? null : _resendOrSendReset,
              child: Text(
                resetStep
                    ? 'Send a new reset code'
                    : 'Resend verification code',
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
  );

  Future<void> _submitCode() async {
    if (resetStep) {
      if (otp.text.trim().length != 6 ||
          !_isStrongPassword(resetPassword.text)) {
        _showMessage('Enter the 6-digit code and a strong new password.');
        return;
      }
      await widget.auth.resetPassword(
        email.text.trim(),
        otp.text.trim(),
        resetPassword.text,
      );
      if (mounted && widget.auth.error == null) {
        setState(() {
          verificationStep = false;
          resetStep = false;
          otp.clear();
          resetPassword.clear();
        });
        _showMessage(
          'Password reset successfully. Log in with your new password.',
        );
      }
    } else {
      if (otp.text.trim().length != 6) {
        _showMessage('Enter the 6-digit verification code.');
        return;
      }
      await widget.auth.verifyEmail(email.text.trim(), otp.text.trim());
      if (mounted && widget.auth.user != null) widget.onChanged();
    }
  }

  Future<void> _resendOrSendReset() async {
    if (resetStep) {
      await widget.auth.forgotPassword(email.text.trim());
    } else {
      await widget.auth.resendVerification(email.text.trim());
    }
    if (mounted && widget.auth.error == null)
      _showMessage('A new code was sent.');
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
  late Future<List<Appointment>> upcomingAppointments;
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
  String? pendingProfilePicture;

  @override
  void initState() {
    super.initState();
    dependents = widget.auth.service.getDependents();
    upcomingAppointments = widget.auth.service.getAppointments(
      scope: 'upcoming',
    );
    profileName = TextEditingController(text: widget.auth.user?.name);
  }

  void _reloadHome() => setState(() {
    dependents = widget.auth.service.getDependents();
    upcomingAppointments = widget.auth.service.getAppointments(
      scope: 'upcoming',
    );
  });

  Future<void> _openHospitals() async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HospitalsScreen(service: widget.auth.service),
      ),
    );
    if (booked == true && mounted) _reloadHome();
  }

  Future<void> _openAppointments() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentsScreen(service: widget.auth.service),
      ),
    );
    if (changed == true && mounted) _reloadHome();
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
      onRefresh: () async => _reloadHome(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Good morning,', style: Theme.of(context).textTheme.bodyLarge),
          Row(
            children: [
              _ProfileAvatar(user: widget.auth.user, radius: 27),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.auth.user?.name ?? 'there',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ],
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
                  onTap: _openHospitals,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.event_note_outlined,
                  label: 'My visits',
                  onTap: _openAppointments,
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
                'Upcoming visits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: _openAppointments,
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _UpcomingAppointments(
            future: upcomingAppointments,
            onTap: _openAppointments,
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
                        _ProfileAvatar(
                          imageData: pendingProfilePicture,
                          user: widget.auth.user,
                          radius: 30,
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton.icon(
                          onPressed: savingProfile
                              ? null
                              : _chooseProfilePicture,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Change photo'),
                        ),
                      ],
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
    setState(() {
      pendingProfilePicture = widget.auth.user?.profilePicture;
      editingProfile = true;
    });
  }

  Future<void> _chooseProfilePicture() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 75,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      pendingProfilePicture = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _saveProfile() async {
    final name = profileName.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter your name first.');
      return;
    }

    setState(() => savingProfile = true);
    try {
      await widget.auth.service.updateProfile({
        'name': name,
        'profilePicture': pendingProfilePicture,
      });
      if (mounted)
        setState(() {
          editingProfile = false;
          savingProfile = false;
          pendingProfilePicture = null;
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.user, this.imageData, required this.radius});

  final User? user;
  final String? imageData;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final source = imageData ?? user?.profilePicture;
    ImageProvider? image;
    if (source != null && source.startsWith('data:image/')) {
      final comma = source.indexOf(',');
      if (comma > 0) {
        try {
          image = MemoryImage(base64Decode(source.substring(comma + 1)));
        } on FormatException {
          image = null;
        }
      }
    } else if (source != null && source.startsWith('https://')) {
      // Google accounts arrive with a hosted avatar URL rather than a data URI.
      image = NetworkImage(source);
    }
    final name = user?.name.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.mint,
      backgroundImage: image,
      child: image == null
          ? Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: TextStyle(fontSize: radius * 0.75, color: AppTheme.navy),
            )
          : null,
    );
  }
}

/// The next few booked visits, shown on the home screen.
class _UpcomingAppointments extends StatelessWidget {
  const _UpcomingAppointments({required this.future, required this.onTap});
  final Future<List<Appointment>> future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Appointment>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return ErrorView(message: '${snapshot.error}');
      }
      final list = snapshot.data ?? const <Appointment>[];
      if (list.isEmpty) {
        return const EmptyView(
          icon: Icons.event_available_outlined,
          message: 'No upcoming visits. Tap Book visit to schedule one.',
        );
      }
      return Column(
        children: [
          for (final appointment in list.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppTheme.mint.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.event_rounded,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.doctorName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppDates.relativeDay(appointment.scheduledAt)}'
                                ' · ${AppDates.time(appointment.scheduledAt)}',
                                style: const TextStyle(
                                  color: AppTheme.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (appointment.hospitalName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  appointment.hospitalName!,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.teal,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
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
