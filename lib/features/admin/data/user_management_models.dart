class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isEmailVerified,
    this.phone,
    this.createdAt,
    this.doctorProfile,
    this.catalogOnly = false,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'patient',
    isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    phone: json['phone'] as String?,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.tryParse(json['createdAt'].toString()),
    doctorProfile: json['doctorProfile'] is Map
        ? Map<String, dynamic>.from(json['doctorProfile'] as Map)
        : null,
    catalogOnly: json['catalogOnly'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isEmailVerified;
  final String? phone;
  final DateTime? createdAt;
  final Map<String, dynamic>? doctorProfile;
  final bool catalogOnly;
}
