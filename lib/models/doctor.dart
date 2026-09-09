/// One recurring block in a doctor's week, e.g. Monday 09:00-12:30.
class ScheduleBlock {
  const ScheduleBlock({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final String day;
  final String startTime;
  final String endTime;

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) => ScheduleBlock(
    day: json['day'] as String? ?? '',
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
  );

  String get label => '$startTime - $endTime';
}

class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialization,
    this.qualifications,
    this.about,
    this.photo,
    this.experienceYears = 0,
    this.consultationFee = 0,
    this.slotMinutes = 30,
    this.hospitalId,
    this.hospitalName,
    this.hospitalCity,
    this.departmentId,
    this.departmentName,
    this.schedule = const [],
  });

  final String id;
  final String name;
  final String specialization;
  final String? qualifications;
  final String? about;
  final String? photo;
  final int experienceYears;
  final num consultationFee;
  final int slotMinutes;
  final String? hospitalId;
  final String? hospitalName;
  final String? hospitalCity;
  final String? departmentId;
  final String? departmentName;
  final List<ScheduleBlock> schedule;

  /// `hospital` and `department` arrive either populated or as a bare id,
  /// depending on the endpoint.
  static Map<String, dynamic>? _object(dynamic value) =>
      value is Map<String, dynamic> ? value : null;

  static String? _id(dynamic value) => value is Map<String, dynamic>
      ? value['_id']?.toString()
      : value?.toString();

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    specialization: json['specialization'] as String? ?? '',
    qualifications: json['qualifications'] as String?,
    about: json['about'] as String?,
    photo: json['photo'] as String?,
    experienceYears: (json['experienceYears'] as num?)?.toInt() ?? 0,
    consultationFee: (json['consultationFee'] as num?) ?? 0,
    slotMinutes: (json['slotMinutes'] as num?)?.toInt() ?? 30,
    hospitalId: _id(json['hospital']),
    hospitalName: _object(json['hospital'])?['name'] as String?,
    hospitalCity: _object(json['hospital'])?['city'] as String?,
    departmentId: _id(json['department']),
    departmentName: _object(json['department'])?['name'] as String?,
    schedule: ((json['schedule'] as List?) ?? [])
        .map((item) => ScheduleBlock.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  String get subtitle => [
    specialization,
    if (departmentName != null) departmentName!,
  ].join(' · ');
}
