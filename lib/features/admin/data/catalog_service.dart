import '../../../services/api_service.dart';
import 'catalog_models.dart';

/// The admin side of the catalog the booking flow reads: cities, hospitals,
/// departments and doctors.
///
/// Deleting is refused by the server while anything still points at a row; the
/// message it sends back says so, and [ApiException] carries it to the UI
/// unchanged rather than being reworded here.
class AdminCatalogService {
  AdminCatalogService(this._api);
  final ApiService _api;

  // --- Cities ---

  Future<List<AdminCity>> cities() async =>
      ((await _api.request('GET', '/admin/cities'))['cities'] as List)
          .map((item) => AdminCity.fromJson(item as Map<String, dynamic>))
          .toList();

  Future<void> createCity(String name) =>
      _api.request('POST', '/admin/cities', body: {'name': name});

  Future<void> renameCity(String from, String to) => _api.request(
    'PATCH',
    '/admin/cities/${Uri.encodeComponent(from)}',
    body: {'name': to},
  );

  Future<void> deleteCity(String name) =>
      _api.request('DELETE', '/admin/cities/${Uri.encodeComponent(name)}');

  // --- Hospitals ---

  Future<List<AdminHospital>> hospitals({String? query, String? city}) async {
    final params = <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (city != null && city.isNotEmpty) 'city': city,
    };
    final data = await _api.request('GET', '/admin/hospitals${_query(params)}');
    return (data['hospitals'] as List)
        .map((item) => AdminHospital.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveHospital({
    String? id,
    required String name,
    required String city,
    String? address,
    String? phone,
    String? about,
    bool active = true,
  }) => _api.request(
    id == null ? 'POST' : 'PATCH',
    id == null ? '/admin/hospitals' : '/admin/hospitals/$id',
    body: {
      'name': name,
      'city': city,
      'address': address ?? '',
      'phone': phone ?? '',
      'about': about ?? '',
      'active': active,
    },
  );

  Future<void> deleteHospital(String id) =>
      _api.request('DELETE', '/admin/hospitals/$id');

  // --- Departments ---

  Future<List<AdminDepartment>> departments({String? hospitalId}) async {
    final params = <String, String>{
      if (hospitalId != null && hospitalId.isNotEmpty) 'hospital': hospitalId,
    };
    final data = await _api.request(
      'GET',
      '/admin/departments${_query(params)}',
    );
    return (data['departments'] as List)
        .map((item) => AdminDepartment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDepartment({
    String? id,
    required String hospitalId,
    required String name,
    String? description,
  }) => _api.request(
    id == null ? 'POST' : 'PATCH',
    id == null ? '/admin/departments' : '/admin/departments/$id',
    body: {
      'hospital': hospitalId,
      'name': name,
      'description': description ?? '',
    },
  );

  Future<void> deleteDepartment(String id) =>
      _api.request('DELETE', '/admin/departments/$id');

  // --- Doctors ---

  Future<List<AdminDoctor>> doctors({
    String? hospitalId,
    String? departmentId,
    String? query,
  }) async {
    final params = <String, String>{
      if (hospitalId != null && hospitalId.isNotEmpty) 'hospital': hospitalId,
      if (departmentId != null && departmentId.isNotEmpty)
        'department': departmentId,
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final data = await _api.request('GET', '/admin/doctors${_query(params)}');
    return (data['doctors'] as List)
        .map((item) => AdminDoctor.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDoctor({
    String? id,
    required String name,
    required String specialization,
    required String hospitalId,
    required String departmentId,
    String? qualifications,
    String? about,
    int experienceYears = 0,
    int consultationFee = 0,
    int slotMinutes = 30,
    bool active = true,
    List<AdminAvailability> availability = const [],
  }) => _api.request(
    id == null ? 'POST' : 'PATCH',
    id == null ? '/admin/doctors' : '/admin/doctors/$id',
    body: {
      'name': name,
      'specialization': specialization,
      'hospital': hospitalId,
      'department': departmentId,
      'qualifications': qualifications ?? '',
      'about': about ?? '',
      'experienceYears': experienceYears,
      'consultationFee': consultationFee,
      'slotMinutes': slotMinutes,
      'active': active,
      'availability': availability.map((slot) => slot.toJson()).toList(),
    },
  );

  Future<void> deleteDoctor(String id) =>
      _api.request('DELETE', '/admin/doctors/$id');

  static String _query(Map<String, String> params) => params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
}
