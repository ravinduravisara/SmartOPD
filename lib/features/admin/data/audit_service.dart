import '../../../services/api_service.dart';

class AuditEntry {
  AuditEntry.fromJson(Map<String, dynamic> json)
    : id = json['_id']?.toString() ?? '',
      action = json['action'] as String? ?? 'UPDATE',
      module = json['module'] as String? ?? 'admin',
      description = json['description'] as String? ?? '',
      statusCode = (json['statusCode'] as num?)?.toInt() ?? 200,
      success = json['success'] as bool? ?? true,
      seen = json['seen'] as bool? ?? false,
      createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      actorName = (json['actor'] as Map?)?['name'] as String? ?? 'Administrator',
      actorEmail = (json['actor'] as Map?)?['email'] as String? ?? '';

  final String id;
  final String action;
  final String module;
  final String description;
  final int statusCode;
  final bool success;
  final bool seen;
  final DateTime? createdAt;
  final String actorName;
  final String actorEmail;
}

class AuditPage {
  AuditPage.fromJson(Map<String, dynamic> json)
    : logs = ((json['logs'] as List?) ?? const [])
          .map((item) => AuditEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      total = (json['total'] as num?)?.toInt() ?? 0,
      page = (json['page'] as num?)?.toInt() ?? 1,
      pages = (json['pages'] as num?)?.toInt() ?? 1;

  final List<AuditEntry> logs;
  final int total;
  final int page;
  final int pages;
}

class AuditService {
  const AuditService(this._api);
  final ApiService _api;

  Future<AuditPage> list({
    String query = '',
    String? module,
    int page = 1,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (module != null && module != 'all') 'module': module,
      'page': '$page',
      'limit': '20',
    };
    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    return AuditPage.fromJson(await _api.request('GET', '/admin/audit$suffix'));
  }

  Future<void> markSeen(String id) =>
      _api.request('PATCH', '/admin/audit/$id/seen');

  Future<void> delete(String id) =>
      _api.request('DELETE', '/admin/audit/$id');
}
