import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
      composing: newValue.composing,
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    required this.service,
    required this.user,
    this.initialFocusNic = false,
    super.key,
  });

  final AuthService service;
  final User user;
  final bool initialFocusNic;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nicController;
  final FocusNode _nicFocusNode = FocusNode();

  DateTime? _selectedDateOfBirth;
  String? _selectedGender;
  String? _pendingProfilePicture;
  bool _isSaving = false;
  String? _errorMessage;

  String? _nameError;
  String? _phoneError;
  String? _nicError;
  String? _dobError;
  String? _genderError;

  final List<String> _genderOptions = [
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _nicController = TextEditingController(text: widget.user.nic ?? '');
    _selectedDateOfBirth = widget.user.dateOfBirth;
    _selectedGender = widget.user.gender;
    _pendingProfilePicture = widget.user.profilePicture;

    if (widget.initialFocusNic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _nicFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nicController.dispose();
    _nicFocusNode.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Full name is required';
    if (v.length < 2) return 'Full name must be at least 2 characters';
    if (v.length > 100) return 'Full name must be 100 characters or fewer';
    if (!RegExp(r"^[a-zA-Z\s\-'.]+$").hasMatch(v)) {
      return 'Full name can only contain letters, spaces, and hyphens';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';
    if (v.length != 10) {
      return 'Phone number must be exactly 10 digits (${v.length}/10)';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(v)) {
      return 'Phone number must contain digits only';
    }
    if (!v.startsWith('0')) {
      return 'Phone number must start with 0 (e.g., 0712345678)';
    }
    return null;
  }

  String? _validateNic(String? value) {
    final v = value?.replaceAll(RegExp(r'[\s\-]'), '').trim() ?? '';
    if (v.isEmpty) return 'NIC number is required';
    final isOldFormat = RegExp(r'^[0-9]{9}[vVxX]$').hasMatch(v);
    final isNewFormat = RegExp(r'^[0-9]{12}$').hasMatch(v);
    if (!isOldFormat && !isNewFormat) {
      return 'Enter valid NIC: 9 digits + V/X or 12 digits';
    }
    return null;
  }

  String? _validateDob(DateTime? date) {
    if (date == null) return 'Please select your date of birth';
    final now = DateTime.now();
    if (date.isAfter(now)) return 'Date of birth cannot be in the future';
    final age = now.year -
        date.year -
        ((now.month < date.month || (now.month == date.month && now.day < date.day))
            ? 1
            : 0);
    if (age > 125) return 'Please enter a valid date of birth';
    return null;
  }

  String? _validateGender(String? gender) {
    if (gender == null || gender.isEmpty) return 'Please select your gender';
    if (!_genderOptions.contains(gender)) return 'Invalid gender option';
    return null;
  }

  bool _validateAll() {
    final nameErr = _validateName(_nameController.text);
    final phoneErr = _validatePhone(_phoneController.text);
    final nicErr = _validateNic(_nicController.text);
    final dobErr = _validateDob(_selectedDateOfBirth);
    final genderErr = _validateGender(_selectedGender);

    setState(() {
      _nameError = nameErr;
      _phoneError = phoneErr;
      _nicError = nicErr;
      _dobError = dobErr;
      _genderError = genderErr;
      if (nameErr != null ||
          phoneErr != null ||
          nicErr != null ||
          dobErr != null ||
          genderErr != null) {
        _errorMessage = 'Please fix the errors highlighted below.';
      } else {
        _errorMessage = null;
      }
    });

    return nameErr == null &&
        phoneErr == null &&
        nicErr == null &&
        dobErr == null &&
        genderErr == null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 75,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pendingProfilePicture = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSurface(
        radius: 24,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Photo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.teal),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.teal),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            if (_pendingProfilePicture != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _pendingProfilePicture = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDateOfBirth ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.teal,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobError = _validateDob(picked);
        if (_errorMessage != null) _validateAll();
      });
    }
  }

  String _formatGender(String? gender) {
    if (gender == null) return 'Select gender';
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
    if (date == null) return 'Select date of birth';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  ImageProvider? _resolveAvatarImage() {
    final source = _pendingProfilePicture;
    if (source != null && source.startsWith('data:image/')) {
      final comma = source.indexOf(',');
      if (comma > 0) {
        try {
          return MemoryImage(base64Decode(source.substring(comma + 1)));
        } catch (_) {
          return null;
        }
      }
    } else if (source != null && source.startsWith('https://')) {
      return NetworkImage(source);
    }
    return null;
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (!_validateAll()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final cleanNic = _nicController.text.replaceAll(RegExp(r'[\s\-]'), '').trim().toUpperCase();

    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'nic': cleanNic,
      if (_selectedDateOfBirth != null)
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String(),
      if (_selectedGender != null) 'gender': _selectedGender,
      'profilePicture': _pendingProfilePicture == '' ? null : _pendingProfilePicture,
    };

    try {
      await widget.service.updateProfile(updates);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppTheme.teal,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isSaving = false;
        _errorMessage = msg;
        if (msg.toLowerCase().contains('nic')) {
          _nicError = msg;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _resolveAvatarImage();
    final initialLetter = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : '?';

    return GlassScaffold(
      title: 'Edit Profile',
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, glassTopInset(context) + 12, 20, 36),
        child: Column(
          children: [
            // Avatar & Change Photo Header
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppTheme.mint,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            initialLetter,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy,
                            ),
                          )
                        : null,
                  ),
                  InkWell(
                    onTap: _showPhotoOptions,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _showPhotoOptions,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Change photo'),
            ),
            const SizedBox(height: 16),

            // Form container
            GlassSurface(
              radius: 24,
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 18),

                  // Full Name
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (val) {
                      setState(() {
                        if (_nameError != null) _nameError = _validateName(val);
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: const Icon(Icons.person_outline),
                      errorText: _nameError,
                      helperText: _nameError == null
                          ? 'As it appears on your official ID'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email (Read-only verified)
                  TextField(
                    controller: TextEditingController(text: widget.user.email),
                    readOnly: true,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: const Icon(Icons.mail_outline),
                      suffixIcon: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2E7D32)),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                      helperText: 'Email address is linked to your account security',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone Number
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (val) {
                      setState(() {
                        if (_phoneError != null) _phoneError = _validatePhone(val);
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      errorText: _phoneError,
                      helperText: _phoneError == null
                          ? 'For appointment reminders and queue alerts'
                          : null,
                      counterText: '${_phoneController.text.length}/10',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // NIC Number
                  TextField(
                    controller: _nicController,
                    focusNode: _nicFocusNode,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9vVxX\s\-]')),
                      LengthLimitingTextInputFormatter(14),
                      _UpperCaseTextFormatter(),
                    ],
                    onChanged: (val) {
                      setState(() {
                        if (_nicError != null) _nicError = _validateNic(val);
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'NIC number',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      errorText: _nicError,
                      helperText: _nicError == null
                          ? 'Old NIC (e.g. 991234567V) or New NIC (e.g. 200012345678)'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  InkWell(
                    onTap: _selectDateOfBirth,
                    borderRadius: BorderRadius.circular(18),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date of birth',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                        errorText: _dobError,
                        helperText: _dobError == null ? 'Patient date of birth' : null,
                      ),
                      child: Text(
                        _formatDate(_selectedDateOfBirth),
                        style: TextStyle(
                          color: _selectedDateOfBirth != null
                              ? AppTheme.navy
                              : AppTheme.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender Selector
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: const Icon(Icons.wc_outlined),
                      errorText: _genderError,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        hint: const Text('Select gender'),
                        items: _genderOptions.map((g) {
                          return DropdownMenuItem<String>(
                            value: g,
                            child: Text(_formatGender(g)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedGender = val;
                            if (_genderError != null) _genderError = _validateGender(val);
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role Display
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 20, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Account Role:',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          widget.user.role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        backgroundColor: AppTheme.mint.withValues(alpha: 0.4),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error Display
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
