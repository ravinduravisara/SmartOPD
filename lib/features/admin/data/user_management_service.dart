import '../../../services/api_service.dart';
import 'user_management_models.dart';

class AdminUserManagementService {
  AdminUserManagementService(this._api);
  final ApiService _api;

  Future<UserPage> users({
    String query = '',
    String? role,
    String? verified,
    int page = 1,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (role case final value? when value != 'all') 'role': value,
      if (verified case final value? when value != 'all') 'verified': value,
      'page': '$page',
      'limit': '25',
    };
    final data = await _api.request('GET', '/admin/users${_query(params)}');
    return UserPage(
      users: (data['users'] as List)
          .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> save({
    String? id,
    required String name,
    required String email,
    required String role,
    String? phone,
    String? password,
    bool? isEmailVerified,
    String? specialization,
    String? hospitalId,
    String? departmentId,
  }) {
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
      'phone': phone?.trim() ?? '',
    };
    if (password?.isNotEmpty ?? false) body['password'] = password;
    if (isEmailVerified != null) body['isEmailVerified'] = isEmailVerified;
    if (role == 'doctor') {
      body['doctorProfile'] = {
        'specialization': specialization,
        'hospital': hospitalId,
        'department': departmentId,
      };
    }
    return _api.request(
      id == null ? 'POST' : 'PATCH',
      id == null ? '/admin/users' : '/admin/users/$id',
      body: body,
    );
  }

  Future<void> delete(String id) => _api.request('DELETE', '/admin/users/$id');

  Future<void> createDoctorAccount({
    required String doctorId,
    required String email,
    required String password,
  }) => _api.request(
    'POST',
    '/admin/doctors/$doctorId/account',
    body: {'email': email.trim(), 'password': password},
  );

  static String _query(Map<String, String> params) =>
      '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
}

class UserPage {
  const UserPage({
    required this.users,
    required this.total,
    required this.page,
    required this.pages,
  });

  final List<AdminUser> users;
  final int total;
  final int page;
  final int pages;
}
