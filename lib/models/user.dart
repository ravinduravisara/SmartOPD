class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.nic,
    this.isEmailVerified = false,
    this.dateOfBirth,
    this.gender,
    this.profilePicture,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? nic;
  final bool isEmailVerified;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? profilePicture;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'patient',
    phone: json['phone'] as String?,
    nic: json['nic'] as String?,
    isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.tryParse(json['dateOfBirth'].toString()),
    gender: json['gender'] as String?,
    profilePicture: json['profilePicture'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'role': role,
    if (phone != null) 'phone': phone,
    if (nic != null) 'nic': nic,
    'isEmailVerified': isEmailVerified,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    if (gender != null) 'gender': gender,
    if (profilePicture != null) 'profilePicture': profilePicture,
  };

  bool get isProfileComplete =>
      (phone != null && phone!.trim().isNotEmpty) &&
      (nic != null && nic!.trim().isNotEmpty) &&
      dateOfBirth != null &&
      (gender != null && gender!.trim().isNotEmpty);

  List<String> get missingProfileFields {
    final list = <String>[];
    if (phone == null || phone!.trim().isEmpty) list.add('phone number');
    if (nic == null || nic!.trim().isEmpty) list.add('NIC number');
    if (dateOfBirth == null) list.add('date of birth');
    if (gender == null || gender!.trim().isEmpty) list.add('gender');
    return list;
  }

  int get profileCompletionPercentage {
    const total = 4;
    int completed = 0;
    if (phone != null && phone!.trim().isNotEmpty) completed++;
    if (nic != null && nic!.trim().isNotEmpty) completed++;
    if (dateOfBirth != null) completed++;
    if (gender != null && gender!.trim().isNotEmpty) completed++;
    return ((completed / total) * 100).round();
  }
}
