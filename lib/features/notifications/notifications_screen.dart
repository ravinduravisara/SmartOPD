import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/glass.dart';
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
    return GlassScaffold(
      title: 'Queue Notifications',
      actions: [
        TextButton(
          onPressed: () => widget.provider.markAllNotificationsRead(),
          child: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final notifications = widget.provider.notifications;

          if (notifications.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: glassTopInset(context)),
              child: const Center(
                child: Text(
                  'No queue notifications yet.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 16 + glassTopInset(context), 16, 24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index] as Map<String, dynamic>;
              final title = n['title'] as String? ?? 'Alert';
              final message = n['message'] as String? ?? '';
              final readStatus = n['readStatus'] as bool? ?? false;
              final type = n['type'] as String? ?? 'PROGRESS';

              final iconInfo = _getNotificationIcon(type);

              return GlassSurface(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                radius: 20,
                tint: readStatus ? null : AppTheme.teal,
                borderColor: readStatus ? null : AppTheme.teal.withValues(alpha: 0.4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconInfo.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: iconInfo.color.withValues(alpha: 0.45)),
                      ),
                      child: Icon(iconInfo.icon, color: iconInfo.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: readStatus ? FontWeight.bold : FontWeight.w900,
                                    color: AppTheme.navy,
                                  ),
                                ),
                              ),
                              if (!readStatus) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.teal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.35),
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
        return (icon: Icons.event_available_rounded, color: AppTheme.teal);
      case 'APPOINTMENT_CANCELLED':
        return (icon: Icons.event_busy_rounded, color: const Color(0xFFE11D48));
      case 'APPOINTMENT_RESCHEDULED':
        return (icon: Icons.edit_calendar_rounded, color: const Color(0xFF4F46E5));
      case 'QUEUE_CONFIRMATION':
        return (icon: Icons.check_circle_rounded, color: const Color(0xFF059669));
      case 'COMPLETED':
        return (icon: Icons.task_alt_rounded, color: AppTheme.textMuted);
      default:
        return (icon: Icons.info_outline_rounded, color: AppTheme.sky);
    }
  }
}
