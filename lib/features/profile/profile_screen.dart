import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.service,
    required this.user,
    this.onUserUpdated,
    super.key,
  });

  final AuthService service;
  final User user;
  final ValueChanged<User>? onUserUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          service: widget.service,
          user: _user,
        ),
      ),
    );

    if (updated == true && mounted) {
      if (widget.service.currentUser != null) {
        setState(() => _user = widget.service.currentUser!);
        widget.onUserUpdated?.call(_user);
      }
    }
  }

  String _formatGender(String? gender) {
    if (gender == null || gender.isEmpty) return 'Not set';
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return gender;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _user.profilePicture;
    ImageProvider? imageProvider;
    if (avatar != null && avatar.startsWith('data:image/')) {
      final comma = avatar.indexOf(',');
      if (comma > 0) {
        try {
          imageProvider = MemoryImage(
            Uri.parse(avatar).data!.contentAsBytes(),
          );
        } catch (_) {}
      }
    } else if (avatar != null && avatar.startsWith('https://')) {
      imageProvider = NetworkImage(avatar);
    }

    final initialLetter =
        _user.name.trim().isNotEmpty ? _user.name.trim()[0].toUpperCase() : '?';

    return GlassScaffold(
      title: 'Profile',
      actions: [
        IconButton(
          tooltip: 'Edit Profile',
          onPressed: _openEditProfile,
          icon: const Icon(Icons.edit_outlined),
        ),
        const SizedBox(width: 8),
      ],
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, glassTopInset(context) + 12, 20, 36),
        children: [
          // Header Card with Avatar & Name
          GlassSurface(
            radius: 28,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.mint,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Text(
                          initialLetter,
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  _user.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _user.email,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF2E7D32),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Chip(
                  label: Text(
                    _user.role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  backgroundColor: AppTheme.mint.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Profile Details List
          GlassSurface(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 14),
                _infoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone number',
                  value: _user.phone?.isNotEmpty == true
                      ? _user.phone!
                      : 'Not provided',
                ),
                const Divider(),
                _infoRow(
                  icon: Icons.badge_outlined,
                  label: 'NIC number',
                  value: _user.nic?.isNotEmpty == true
                      ? _user.nic!
                      : 'Not provided',
                ),
                const Divider(),
                _infoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Date of birth',
                  value: _formatDate(_user.dateOfBirth),
                ),
                const Divider(),
                _infoRow(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: _formatGender(_user.gender),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.teal),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}

