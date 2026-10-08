import '../../../services/api_service.dart';

class AdminDashboardMetrics {
  AdminDashboardMetrics.fromJson(Map<String, dynamic> json)
    : generatedAt = DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      totals = _numbers(json['totals']),
      usersByRole = _numbers(json['usersByRole']),
      appointmentsByStatus = _numbers(json['appointmentsByStatus']),
      queueByStatus = _numbers(json['queueByStatus']),
      hourlyAppointments = ((json['hourlyAppointments'] as List?) ?? const [])
          .map((item) => DashboardPoint.fromJson(item as Map<String, dynamic>))
          .toList();

  final DateTime? generatedAt;
  final Map<String, int> totals;
  final Map<String, int> usersByRole;
  final Map<String, int> appointmentsByStatus;
  final Map<String, int> queueByStatus;
  final List<DashboardPoint> hourlyAppointments;

  int total(String key) => totals[key] ?? 0;

  static Map<String, int> _numbers(dynamic value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }
}

class DashboardPoint {
  const DashboardPoint({required this.hour, required this.count});

  DashboardPoint.fromJson(Map<String, dynamic> json)
    : hour = (json['hour'] as num?)?.toInt() ?? 0,
      count = (json['count'] as num?)?.toInt() ?? 0;

  final int hour;
  final int count;
}

class AdminDashboardService {
  const AdminDashboardService(this._api);
  final ApiService _api;

  Future<AdminDashboardMetrics> metrics() async {
    final response = await _api.request('GET', '/admin/dashboard/metrics');
    return AdminDashboardMetrics.fromJson(response);
  }
}
