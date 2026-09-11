import 'package:flutter/material.dart';
import '../queue/queue_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.provider, super.key});
  final QueueProvider provider;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Queue Notifications'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: () => widget.provider.markAllNotificationsRead(),
            child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final notifications = widget.provider.notifications;

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No queue notifications yet.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final n = notifications[index] as Map<String, dynamic>;
              final title = n['title'] as String? ?? 'Alert';
              final message = n['message'] as String? ?? '';
              final readStatus = n['readStatus'] as bool? ?? false;
              final type = n['type'] as String? ?? 'PROGRESS';

              final iconInfo = _getNotificationIcon(type);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: readStatus ? Colors.white : const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(16),
                  border: readStatus ? null : Border.all(color: const Color(0xFFBAE6FD)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconInfo.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconInfo.icon, color: iconInfo.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: readStatus ? FontWeight.bold : FontWeight.w900,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  ({IconData icon, Color color}) _getNotificationIcon(String type) {
    switch (type) {
      case 'YOUR_TURN':
        return (icon: Icons.notifications_active_rounded, color: const Color(0xFF16A34A));
      case 'YOURE_NEXT':
        return (icon: Icons.directions_walk_rounded, color: const Color(0xFFD97706));
      case 'APPROACHING_TURN':
        return (icon: Icons.access_time_filled_rounded, color: const Color(0xFF2563EB));
      case 'DELAY':
        return (icon: Icons.warning_amber_rounded, color: const Color(0xFFDC2626));
      case 'APPOINTMENT_REMINDER':
        return (icon: Icons.alarm_rounded, color: const Color(0xFF7C3AED));
      case 'APPOINTMENT_CONFIRMATION':
        return (icon: Icons.event_available_rounded, color: const Color(0xFF0D9488));
      case 'APPOINTMENT_CANCELLED':
        return (icon: Icons.event_busy_rounded, color: const Color(0xFFE11D48));
      case 'APPOINTMENT_RESCHEDULED':
        return (icon: Icons.edit_calendar_rounded, color: const Color(0xFF4F46E5));
      case 'QUEUE_CONFIRMATION':
        return (icon: Icons.check_circle_rounded, color: const Color(0xFF059669));
      case 'COMPLETED':
        return (icon: Icons.task_alt_rounded, color: const Color(0xFF475569));
      default:
        return (icon: Icons.info_outline_rounded, color: const Color(0xFF0284C7));
    }
  }
}
