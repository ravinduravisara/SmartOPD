class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.dateOfBirth,
    this.gender,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? gender;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'patient',
    phone: json['phone'] as String?,
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.tryParse(json['dateOfBirth'].toString()),
    gender: json['gender'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'role': role,
    if (phone != null) 'phone': phone,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    if (gender != null) 'gender': gender,
  };
}
