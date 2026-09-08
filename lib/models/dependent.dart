class Dependent {
  const Dependent({
    required this.id,
    required this.name,
    required this.relationship,
    required this.dateOfBirth,
    this.gender,
    this.phone,
  });

  final String id;
  final String name;
  final String relationship;
  final DateTime dateOfBirth;
  final String? gender;
  final String? phone;

  factory Dependent.fromJson(Map<String, dynamic> json) => Dependent(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    relationship: json['relationship'] as String? ?? '',
    dateOfBirth: DateTime.parse(json['dateOfBirth'].toString()),
    gender: json['gender'] as String?,
    phone: json['phone'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'relationship': relationship,
    'dateOfBirth': dateOfBirth.toIso8601String(),
    if (gender != null) 'gender': gender,
    if (phone != null) 'phone': phone,
  };
}
