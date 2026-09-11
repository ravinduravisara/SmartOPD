import 'dart:async';
import 'package:flutter/material.dart';
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
      notifyListeners();
    }

    try {
      final res = await queueService.getActiveQueue();
      if (res != null) {
        activeQueueData = res['queue'] as Map<String, dynamic>?;
        activeMetrics = res['metrics'] as Map<String, dynamic>?;

        // If we have a patient ID and socket isn't connected, connect it
        final pId = activeQueueData?['patientId'] as String?;
        if (pId != null && _currentPatientId == null) {
          _currentPatientId = pId;
          _connectSocket(pId);
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
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<bool> checkIn(String appointmentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await queueService.checkIn(appointmentId);
      activeQueueData = res['queue'] as Map<String, dynamic>?;
      activeMetrics = res['metrics'] as Map<String, dynamic>?;
      isLoading = false;
      notifyListeners();

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
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    try {
      final res = await queueService.getNotifications();
      notifications = res['notifications'] as List<dynamic>? ?? [];
      unreadNotificationsCount = res['unreadCount'] as int? ?? 0;
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
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchNearbyHospitals() async {
    try {
      nearbyHospitals = await queueService.getNearbyHospitals();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchHistory() async {
    try {
      queueHistory = await queueService.getQueueHistory();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}
