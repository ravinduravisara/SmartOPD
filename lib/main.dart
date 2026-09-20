import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'config/theme.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/appointments/appointments_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/hospitals/hospitals_screen.dart';
import 'models/appointment.dart';
import 'models/dependent.dart';
import 'models/user.dart';
import 'utils/date_utils.dart';
import 'widgets/error_widget.dart';
import 'widgets/glass.dart';
import 'services/queue_service.dart';
import 'features/queue/queue_provider.dart';
import 'features/queue/queue_screen.dart';
import 'features/queue/queue_history_screen.dart';
import 'features/queue/widgets/live_queue_home_card.dart';
import 'features/queue_assistant/smart_queue_assistant_screen.dart';
import 'features/notifications/notifications_screen.dart';

void main() => runApp(const SmartOpdApp());

/// Android's default overscroll stretches the whole viewport through an image
/// filter on every frame, and the translucent app bar then has to blur that
/// filtered layer again - two full-screen passes per frame while pulling.
/// Dropping the indicator removes one of them; the refresh spinner is still
/// the feedback for a pull. (A glow indicator is not cheaper: it repaints the
/// viewport too.)
class _GlassScrollBehavior extends MaterialScrollBehavior {
  const _GlassScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

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
    scrollBehavior: const _GlassScrollBehavior(),
    // Without this the provider's `loading` and `error` never reach the UI, so
    // a failed sign-in looks like the button simply did nothing.
    home: ListenableBuilder(
      listenable: auth,
      builder: (context, _) => auth.user == null
          ? AuthScreen(auth: auth, onChanged: () => setState(() {}))
          : auth.user!.role == 'admin'
          ? AdminDashboardScreen(auth: auth)
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
  Widget build(BuildContext context) => GlassScaffold(
    appBar: false,
    body: verificationStep
        ? _verificationView(context)
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassSurface(
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: GlassSurface(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
  late final QueueProvider queueProvider;

  @override
  void initState() {
    super.initState();
    queueProvider = QueueProvider(QueueService(widget.auth.service.api));
    queueProvider.startLiveTracking();
    dependents = widget.auth.service.getDependents();
    upcomingAppointments = widget.auth.service.getAppointments(
      scope: 'upcoming',
    );
    profileName = TextEditingController(text: widget.auth.user?.name);
  }

  void _reloadHome() => setState(() {
    queueProvider.fetchActiveQueue();
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
        builder: (_) => AppointmentsScreen(
          service: widget.auth.service,
          queueProvider: queueProvider,
        ),
      ),
    );
    if (changed == true && mounted) _reloadHome();
  }

  @override
  void dispose() {
    queueProvider.stopLiveTracking();
    dependentName.dispose();
    dependentRelationship.dispose();
    editDependentName.dispose();
    editDependentRelationship.dispose();
    profileName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
    titleWidget: const _BrandLockup(compact: true),
    actions: [
      ListenableBuilder(
        listenable: queueProvider,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(provider: queueProvider),
                  ),
                );
              },
            ),
            if (queueProvider.unreadNotificationsCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${queueProvider.unreadNotificationsCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Log out',
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded),
      ),
      const SizedBox(width: 8),
    ],
    body: RefreshIndicator(
      onRefresh: () async => _reloadHome(),
      // Without this the spinner is drawn at the very top of the list, which
      // is behind the translucent app bar.
      edgeOffset: glassTopInset(context),
      color: AppTheme.teal,
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, glassTopInset(context), 20, 32),
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
          const SizedBox(height: 18),
          LiveQueueHomeCard(provider: queueProvider),
          const SizedBox(height: 18),
          const _CareCard(),
          const SizedBox(height: 28),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // IntrinsicHeight gives the row a height to stretch into, so every
          // tile matches the tallest even when a slab label wraps.
          IntrinsicHeight(
            child: Row(
              // Slab labels can wrap, so let every tile match the tallest.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Live Queue',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QueueScreen(provider: queueProvider),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          // IntrinsicHeight gives the row a height to stretch into, so every
          // tile matches the tallest even when a slab label wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.smart_toy_outlined,
                    label: 'Queue AI',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SmartQueueAssistantScreen(
                            provider: queueProvider,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.history_outlined,
                    label: 'Queue History',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              QueueHistoryScreen(provider: queueProvider),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
            GlassSurface(
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
            GlassSurface(
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
                        onPressed: savingProfile ? null : _chooseProfilePicture,
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
          ],
        ],
      ),
    ),
  );

  Widget _dependentTile(Dependent dependent) {
    if (editingDependentId == dependent.id) {
      return GlassSurface(
        margin: const EdgeInsets.only(bottom: 12),
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
      );
    }

    final initial = dependent.name.trim().isEmpty
        ? '?'
        : dependent.name.trim().substring(0, 1).toUpperCase();
    final deleting = deletingDependentId == dependent.id;
    return GlassSurface(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.mint.withValues(alpha: 0.55),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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

/// Decoded profile photos, keyed by their data URI.
///
/// Decoding on every build would hand Flutter a new byte list each time, which
/// misses the image cache and re-uploads the photo to the GPU — a visible
/// stutter every time the home screen rebuilds, such as on pull to refresh.
final Map<String, MemoryImage?> _avatarImages = {};

MemoryImage? _decodeAvatar(String source) =>
    _avatarImages.putIfAbsent(source, () {
      final comma = source.indexOf(',');
      if (comma <= 0) return null;
      try {
        return MemoryImage(base64Decode(source.substring(comma + 1)));
      } on FormatException {
        return null;
      }
    });

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
      image = _decodeAvatar(source);
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
            GlassSurface(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              onTap: onTap,
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
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.teal),
                ],
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
  Widget build(BuildContext context) => GlassSurface(
    radius: 24,
    tint: AppTheme.mint,
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your care, simplified',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your appointments and loved ones close.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(
          Icons.favorite_outline_rounded,
          color: AppTheme.teal,
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
  Widget build(BuildContext context) => GlassSurface(
    radius: 20,
    onTap: onTap,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.mint.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppTheme.teal),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 14),
        ),
      ],
    ),
  );
}

class _EmptyDependents extends StatelessWidget {
  const _EmptyDependents();

  @override
  Widget build(BuildContext context) => GlassSurface(
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
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
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
