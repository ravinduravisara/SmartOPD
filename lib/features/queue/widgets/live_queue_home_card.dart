import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../widgets/glass.dart';
import '../queue_provider.dart';
import '../queue_screen.dart';

class LiveQueueHomeCard extends StatelessWidget {
  const LiveQueueHomeCard({required this.provider, super.key});
  final QueueProvider provider;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final activeQueue = provider.activeQueueData;
        final metrics = provider.activeMetrics;

        if (activeQueue == null) {
          return const SizedBox.shrink();
        }

        final token = activeQueue['tokenNumber'] as String? ?? 'A-000';
        final currentToken = metrics?['currentToken'] as String? ?? 'None';
        final ahead = metrics?['patientsAhead'] as int? ?? 0;
        final eta = metrics?['estimatedWaitMinutes'] as int? ?? 0;

        return GlassHeroSurface(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.mint.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.mint.withValues(alpha: 0.45)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: AppTheme.mint, size: 8),
                            SizedBox(width: 5),
                            Text(
                              'LIVE QUEUE',
                              style: TextStyle(
                                color: AppTheme.mint,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Token $token',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem('Now Serving', currentToken),
                  _statItem('Ahead', '$ahead'),
                  _statItem('ETA', '~${eta}m'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => QueueScreen(provider: provider)),
                    );
                  },
                  child: const Text('View Full Live Queue', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
