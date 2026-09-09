class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.city,
    this.address,
    this.phone,
    this.about,
    this.doctorCount = 0,
  });

  final String id;
  final String name;
  final String city;
  final String? address;
  final String? phone;
  final String? about;
  final int doctorCount;

  factory Hospital.fromJson(Map<String, dynamic> json) => Hospital(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    about: json['about'] as String?,
    doctorCount: (json['doctorCount'] as num?)?.toInt() ?? 0,
  );
}

class Department {
  const Department({
    required this.id,
    required this.name,
    this.description,
    this.doctorCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final int doctorCount;

  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    doctorCount: (json['doctorCount'] as num?)?.toInt() ?? 0,
  );
}

class HospitalDetails {
  const HospitalDetails({required this.hospital, required this.departments});
  final Hospital hospital;
  final List<Department> departments;
}
