import 'api_service.dart';

class QueueService {
  QueueService(this.apiService);
  final ApiService apiService;

  Future<Map<String, dynamic>> checkIn(String appointmentId) async {
    final response = await apiService.request('POST', '/queues/check-in', body: {
      'appointmentId': appointmentId,
    });
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getActiveQueue() async {
    final response = await apiService.request('GET', '/queues/active');
    final data = response['data'];
    return data != null ? data as Map<String, dynamic> : null;
  }

  Future<List<dynamic>> getQueueHistory() async {
    final response = await apiService.request('GET', '/queues/history');
    return response['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getNearbyHospitals() async {
    final response = await apiService.request('GET', '/queues/nearby-hospitals');
    return response['data'] as List<dynamic>? ?? [];
  }

  Future<String> askQueueAssistant(String query, {String language = 'en'}) async {
    final response = await apiService.request('POST', '/queues/assistant', body: {
      'query': query,
      'language': language,
    });
    return response['reply'] as String? ?? 'No response received.';
  }

  Future<Map<String, dynamic>> getNotifications() async {
    final response = await apiService.request('GET', '/notifications');
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> markNotificationRead(String id) async {
    await apiService.request('PATCH', '/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await apiService.request('POST', '/notifications/read-all');
  }

  Future<Map<String, dynamic>> updateQueue(
    String queueId, {
    String? notes,
    String? specialNeeds,
    int? priority,
  }) async {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    if (specialNeeds != null) body['specialNeeds'] = specialNeeds;
    if (priority != null) body['priority'] = priority;

    final response = await apiService.request('PATCH', '/queues/$queueId', body: body);
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> cancelQueue(String queueId) async {
    await apiService.request('DELETE', '/queues/$queueId');
  }

  Future<void> deleteNotification(String notificationId) async {
    await apiService.request('DELETE', '/notifications/$notificationId');
  }

  Future<void> clearAllNotifications() async {
    await apiService.request('DELETE', '/notifications');
  }
}
