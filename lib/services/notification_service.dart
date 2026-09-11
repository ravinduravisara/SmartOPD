import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service for SmartOPD.
/// Shows device-level notifications for queue alerts (YOUR_TURN, YOURE_NEXT, DELAY)
/// and appointment reminders without requiring Firebase/FCM setup.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin. Call once at app startup.
  Future<void> init() async {
    if (_initialized) return;

    // Skip initialization on web — local notifications don't work on web
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Show a local notification for a queue event.
  Future<void> showQueueNotification({
    required String title,
    required String message,
    required String type,
  }) async {
    if (kIsWeb || !_initialized) return;

    final channelInfo = _channelForType(type);

    final androidDetails = AndroidNotificationDetails(
      channelInfo.id,
      channelInfo.name,
      channelDescription: channelInfo.description,
      importance: channelInfo.importance,
      priority: channelInfo.priority,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      type.hashCode,  // Unique ID per notification type
      title,
      message,
      details,
    );
  }

  /// Show an appointment reminder notification.
  Future<void> showAppointmentReminder({
    required String doctorName,
    required String hospitalName,
    required int minutesUntil,
  }) async {
    await showQueueNotification(
      title: 'Appointment Reminder ⏰',
      message: 'Your appointment with $doctorName at $hospitalName is in $minutesUntil minutes. Please check in when you arrive!',
      type: 'APPOINTMENT_REMINDER',
    );
  }

  /// Map notification types to Android notification channels
  _ChannelInfo _channelForType(String type) {
    return switch (type) {
      'YOUR_TURN' => const _ChannelInfo(
        id: 'smartopd_your_turn',
        name: 'Your Turn Alerts',
        description: 'High-priority alert when it is your turn',
        importance: Importance.max,
        priority: Priority.high,
      ),
      'YOURE_NEXT' => const _ChannelInfo(
        id: 'smartopd_next',
        name: 'Next in Line Alerts',
        description: 'Alert when you are next in the queue',
        importance: Importance.high,
        priority: Priority.high,
      ),
      'DELAY' => const _ChannelInfo(
        id: 'smartopd_delay',
        name: 'Delay Alerts',
        description: 'Notifications about queue delays',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      'APPOINTMENT_REMINDER' => const _ChannelInfo(
        id: 'smartopd_reminders',
        name: 'Appointment Reminders',
        description: 'Reminders before your scheduled appointment',
        importance: Importance.high,
        priority: Priority.high,
      ),
      _ => const _ChannelInfo(
        id: 'smartopd_general',
        name: 'Queue Updates',
        description: 'General queue status updates',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    };
  }
}

class _ChannelInfo {
  const _ChannelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.priority,
  });

  final String id;
  final String name;
  final String description;
  final Importance importance;
  final Priority priority;
}
