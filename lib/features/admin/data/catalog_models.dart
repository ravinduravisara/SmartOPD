/// Catalog rows as the admin endpoints return them. These carry the counts and
/// the `active` flag that the patient-facing models leave out, because the
/// admin needs to see what a row is attached to before deleting it.
class AdminCity {
  const AdminCity({required this.name, required this.hospitalCount});

  factory AdminCity.fromJson(Map<String, dynamic> json) => AdminCity(
    name: json['name'] as String? ?? '',
    hospitalCount: (json['hospitalCount'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final int hospitalCount;
}

class AdminHospital {
  const AdminHospital({
    required this.id,
    required this.name,
    required this.city,
    this.address,
    this.phone,
    this.about,
    this.active = true,
    this.departmentCount = 0,
    this.doctorCount = 0,
  });

  factory AdminHospital.fromJson(Map<String, dynamic> json) => AdminHospital(
    id: json['id'] as String? ?? json['_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    about: json['about'] as String?,
    active: json['active'] as bool? ?? true,
    departmentCount: (json['departmentCount'] as num?)?.toInt() ?? 0,
    doctorCount: (json['doctorCount'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String name;
  final String city;
  final String? address;
  final String? phone;
  final String? about;
  final bool active;
  final int departmentCount;
  final int doctorCount;
}

/// The hospital or department a row hangs off, as embedded in admin responses.
class AdminRef {
  const AdminRef({required this.id, required this.name, this.city});

  factory AdminRef.fromJson(Map<String, dynamic> json) => AdminRef(
    id: json['id'] as String? ?? json['_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    city: json['city'] as String?,
  );

  final String id;
  final String name;
  final String? city;

  String get label => city == null || city!.isEmpty ? name : '$name · $city';
}

class AdminDepartment {
  const AdminDepartment({
    required this.id,
    required this.name,
    required this.hospital,
    this.description,
    this.doctorCount = 0,
  });

  factory AdminDepartment.fromJson(Map<String, dynamic> json) =>
      AdminDepartment(
        id: json['id'] as String? ?? json['_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        hospital: AdminRef.fromJson(
          (json['hospital'] as Map<String, dynamic>?) ?? const {},
        ),
        description: json['description'] as String?,
        doctorCount: (json['doctorCount'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final AdminRef hospital;
  final String? description;
  final int doctorCount;
}

/// One recurring weekly block, e.g. Monday 09:00-12:00.
class AdminAvailability {
  const AdminAvailability({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory AdminAvailability.fromJson(Map<String, dynamic> json) =>
      AdminAvailability(
        dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
        startTime: json['startTime'] as String? ?? '09:00',
        endTime: json['endTime'] as String? ?? '17:00',
      );

  final int dayOfWeek;
  final String startTime;
  final String endTime;

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
  };

  static const dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String get dayName => dayNames[dayOfWeek % 7];
  String get range => '$startTime - $endTime';
}

class AdminDoctor {
  const AdminDoctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.hospital,
    required this.department,
    this.qualifications,
    this.about,
    this.experienceYears = 0,
    this.consultationFee = 0,
    this.slotMinutes = 30,
    this.active = true,
    this.availability = const [],
  });

  factory AdminDoctor.fromJson(Map<String, dynamic> json) => AdminDoctor(
    id: json['id'] as String? ?? json['_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    specialization: json['specialization'] as String? ?? '',
    hospital: AdminRef.fromJson(
      (json['hospital'] as Map<String, dynamic>?) ?? const {},
    ),
    department: AdminRef.fromJson(
      (json['department'] as Map<String, dynamic>?) ?? const {},
    ),
    qualifications: json['qualifications'] as String?,
    about: json['about'] as String?,
    experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
    consultationFee: (json['consultationFee'] as num?)?.toInt() ?? 0,
    slotMinutes: (json['slotMinutes'] as num?)?.toInt() ?? 30,
    active: json['active'] as bool? ?? true,
    availability: ((json['availability'] as List?) ?? const [])
        .map((item) => AdminAvailability.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final String name;
  final String specialization;
  final AdminRef hospital;
  final AdminRef department;
  final String? qualifications;
  final String? about;
  final int experienceYears;
  final int consultationFee;
  final int slotMinutes;
  final bool active;
  final List<AdminAvailability> availability;
}
