enum AppointmentStatus { booked, cancelled, completed }

class Appointment {
  const Appointment({
    required this.id,
    required this.scheduledAt,
    required this.status,
    required this.doctorId,
    required this.doctorName,
    this.doctorSpecialization,
    this.consultationFee = 0,
    this.hospitalName,
    this.hospitalAddress,
    this.hospitalPhone,
    this.departmentName,
    this.dependentName,
    this.dependentRelationship,
    this.reason,
    this.durationMinutes = 30,
    this.rescheduledFrom,
  });

  final String id;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final String doctorId;
  final String doctorName;
  final String? doctorSpecialization;
  final num consultationFee;
  final String? hospitalName;
  final String? hospitalAddress;
  final String? hospitalPhone;
  final String? departmentName;
  final String? dependentName;
  final String? dependentRelationship;
  final String? reason;
  final int durationMinutes;
  final DateTime? rescheduledFrom;

  static Map<String, dynamic>? _object(dynamic value) =>
      value is Map<String, dynamic> ? value : null;

  static String? _id(dynamic value) => value is Map<String, dynamic>
      ? value['_id']?.toString()
      : value?.toString();

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final doctor = _object(json['doctor']);
    final hospital = _object(json['hospital']);
    final dependent = _object(json['dependent']);
    return Appointment(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'].toString()).toLocal(),
      status: AppointmentStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => AppointmentStatus.booked,
      ),
      doctorId: _id(json['doctor']) ?? '',
      doctorName: doctor?['name'] as String? ?? 'Doctor',
      doctorSpecialization: doctor?['specialization'] as String?,
      consultationFee: (doctor?['consultationFee'] as num?) ?? 0,
      hospitalName: hospital?['name'] as String?,
      hospitalAddress: hospital?['address'] as String?,
      hospitalPhone: hospital?['phone'] as String?,
      departmentName: _object(json['department'])?['name'] as String?,
      dependentName: dependent?['name'] as String?,
      dependentRelationship: dependent?['relationship'] as String?,
      reason: json['reason'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      rescheduledFrom: json['rescheduledFrom'] == null
          ? null
          : DateTime.parse(json['rescheduledFrom'].toString()).toLocal(),
    );
  }

  /// Who the visit is for — a dependent when booked on their behalf.
  String get patientLabel => dependentName ?? 'Myself';

  bool get isUpcoming =>
      status == AppointmentStatus.booked && scheduledAt.isAfter(DateTime.now());

  /// Cancelling and rescheduling are only offered while the visit is still
  /// ahead; the backend enforces the same rule.
  bool get canModify => isUpcoming;
}
