import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../services/queue_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_service.dart';

class QueueProvider extends ChangeNotifier {
  QueueProvider(this.queueService);

  final QueueService queueService;
  final SocketService _socketService = SocketService();
  final NotificationService _notificationService = NotificationService();

  bool isLoading = false;
  String? error;

  Map<String, dynamic>? activeQueueData;
  Map<String, dynamic>? activeMetrics;

  List<dynamic> notifications = [];
  int unreadNotificationsCount = 0;

  List<dynamic> nearbyHospitals = [];
  List<dynamic> queueHistory = [];

  Timer? _pollingTimer;
  String? _currentPatientId;

  bool _notificationPending = false;

  void _safeNotify() {
    if (_notificationPending) return;
    _notificationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationPending = false;
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  void startLiveTracking({String? patientId}) {
    fetchActiveQueue();
    fetchNotifications();
    _pollingTimer?.cancel();
    // Poll every 5 seconds as a reliable fallback for real-time data
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchActiveQueue(silent: true);
      fetchNotifications(silent: true);
    });

    // Initialize local notifications
    _notificationService.init();

    // Connect WebSocket for real-time push updates
    if (patientId != null) {
      _currentPatientId = patientId;
      _connectSocket(patientId);
    }
  }

  void _connectSocket(String patientId) {
    _socketService.connect(
      patientId: patientId,
      onQueueUpdated: () {
        // Socket received a queue update — refresh data immediately
        fetchActiveQueue(silent: true);
        fetchNotifications(silent: true);
      },
      onNotification: (notification) {
        // Show local device notification for important alerts
        final title = notification['title'] as String? ?? 'Queue Update';
        final message = notification['message'] as String? ?? '';
        final type = notification['type'] as String? ?? 'PROGRESS';

        _notificationService.showQueueNotification(
          title: title,
          message: message,
          type: type,
        );

        // Also refresh notification list
        fetchNotifications(silent: true);
      },
    );
  }

  void stopLiveTracking() {
    _pollingTimer?.cancel();
    _socketService.disconnect();
  }

  Future<void> fetchActiveQueue({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      error = null;
      _safeNotify();
    }

    try {
      final res = await queueService.getActiveQueue();
      if (res != null) {
        activeQueueData = res['queue'] as Map<String, dynamic>?;
        activeMetrics = res['metrics'] as Map<String, dynamic>?;

        // If we have a patient ID and socket isn't connected, connect it
        final pId = activeQueueData?['patientId']?.toString();
        if (pId != null) {
          if (_currentPatientId == null) {
            _currentPatientId = pId;
            _connectSocket(pId);
          } else {
            _socketService.updatePatientId(pId);
          }
        }
      } else {
        activeQueueData = null;
        activeMetrics = null;
      }
    } catch (e) {
      if (!silent) error = e.toString();
    } finally {
      if (!silent) {
        isLoading = false;
        _safeNotify();
      } else {
        _safeNotify();
      }
    }
  }

  Future<bool> checkIn(String appointmentId) async {
    isLoading = true;
    error = null;
    _safeNotify();

    try {
      final res = await queueService.checkIn(appointmentId);
      activeQueueData = res['queue'] as Map<String, dynamic>?;
      activeMetrics = res['metrics'] as Map<String, dynamic>?;
      isLoading = false;
      _safeNotify();

      // Show local notification for successful check-in
      final token = activeQueueData?['tokenNumber'] as String? ?? '';
      _notificationService.showQueueNotification(
        title: 'Check-in Confirmed ✅',
        message: 'Your queue token $token is confirmed. We\'ll notify you when your turn approaches!',
        type: 'QUEUE_CONFIRMATION',
      );

      startLiveTracking(patientId: activeQueueData?['patientId']?.toString());
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    try {
      final res = await queueService.getNotifications();
      notifications = res['notifications'] as List<dynamic>? ?? [];
      unreadNotificationsCount = res['unreadCount'] as int? ?? 0;
      _safeNotify();
    } catch (_) {}
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      await queueService.markNotificationRead(notificationId);
      final idx = notifications.indexWhere((n) => (n as Map<String, dynamic>)['_id'] == notificationId);
      if (idx != -1) {
        final notif = notifications[idx] as Map<String, dynamic>;
        if (notif['readStatus'] != true) {
          notif['readStatus'] = true;
          if (unreadNotificationsCount > 0) {
            unreadNotificationsCount--;
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await queueService.markAllNotificationsRead();
      unreadNotificationsCount = 0;
      for (var n in notifications) {
        if (n is Map<String, dynamic>) n['readStatus'] = true;
      }
      _safeNotify();
    } catch (_) {}
  }

  Future<bool> updateQueue(String queueId, {String? notes, String? specialNeeds}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await queueService.updateQueue(
        queueId,
        notes: notes,
        specialNeeds: specialNeeds,
      );
      if (activeQueueData != null) {
        if (notes != null) activeQueueData!['notes'] = notes;
        if (specialNeeds != null) activeQueueData!['specialNeeds'] = specialNeeds;
      }
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelQueue(String queueId) async {
    try {
      await queueService.cancelQueue(queueId);
      activeQueueData = null;
      activeMetrics = null;
      _safeNotify();
      return true;
    } catch (e) {
      error = e.toString();
      _safeNotify();
      return false;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await queueService.deleteNotification(notificationId);
      notifications.removeWhere((n) => (n as Map<String, dynamic>)['_id'] == notificationId);
      _safeNotify();
    } catch (_) {}
  }

  Future<void> clearAllNotifications() async {
    try {
      await queueService.clearAllNotifications();
      notifications.clear();
      unreadNotificationsCount = 0;
      _safeNotify();
    } catch (_) {}
  }

  Future<void> fetchNearbyHospitals() async {
    try {
      nearbyHospitals = await queueService.getNearbyHospitals();
      _safeNotify();
    } catch (_) {}
  }

  Future<void> fetchHistory() async {
    try {
      queueHistory = await queueService.getQueueHistory();
      _safeNotify();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
