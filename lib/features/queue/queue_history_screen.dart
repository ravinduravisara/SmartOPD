import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/glass.dart';
import 'queue_provider.dart';

class QueueHistoryScreen extends StatefulWidget {
  const QueueHistoryScreen({required this.provider, super.key});
  final QueueProvider provider;

  @override
  State<QueueHistoryScreen> createState() => _QueueHistoryScreenState();
}

class _QueueHistoryScreenState extends State<QueueHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Queue History',
      body: ListenableBuilder(
        listenable: widget.provider,
        builder: (context, _) {
          final history = widget.provider.queueHistory;

          if (history.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: glassTopInset(context)),
              child: const Center(
                child: Text(
                  'No past queue sessions found.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16 + glassTopInset(context), 16, 24),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = history[index] as Map<String, dynamic>;
              final hospital = item['hospitalId'] as Map<String, dynamic>? ?? {};
              final doctor = item['doctorId'] as Map<String, dynamic>? ?? {};
              final token = item['tokenNumber'] as String? ?? 'A-000';
              final status = item['status'] as String? ?? 'COMPLETED';

              final isCompleted = status == 'COMPLETED';
              final statusColour = isCompleted ? AppTheme.teal : AppTheme.textMuted;

              return GlassSurface(
                padding: const EdgeInsets.all(16),
                radius: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        token,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospital['name'] as String? ?? 'Hospital',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doctor['name'] as String? ?? 'Doctor',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColour.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColour.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColour,
                        ),
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
}
