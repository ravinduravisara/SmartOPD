import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/glass.dart';
import 'queue_provider.dart';
import 'queue_history_screen.dart';
import '../queue_assistant/smart_queue_assistant_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({required this.provider, super.key});
  final QueueProvider provider;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    widget.provider.startLiveTracking();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final provider = widget.provider;

        return GlassScaffold(
          titleWidget: Row(
            children: [
              const Flexible(
                child: Text(
                  'Live Queue Status',
                  style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.teal.withValues(alpha: 0.45)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: AppTheme.teal, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(color: AppTheme.teal, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.smart_toy_rounded, color: AppTheme.teal),
              tooltip: 'Queue AI Assistant',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SmartQueueAssistantScreen(provider: provider)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppTheme.navy),
              tooltip: 'Queue History',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => QueueHistoryScreen(provider: provider)),
                );
              },
            ),
          ],
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.activeQueueData == null
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      onRefresh: () => provider.fetchActiveQueue(),
                      // Keeps the spinner clear of the translucent app bar.
                      edgeOffset: glassTopInset(context),
                      color: AppTheme.teal,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 20 + glassTopInset(context), 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHospitalHeader(provider),
                            const SizedBox(height: 20),
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: _buildDigitalTokenCard(provider),
                            ),
                            const SizedBox(height: 20),
                            _buildMetricsRow(provider),
                            const SizedBox(height: 20),
                            _buildStatusBanner(provider),
                            const SizedBox(height: 24),
                            _buildProgressTimeline(provider),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32 + glassTopInset(context), 32, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Icon(Icons.confirmation_number_outlined, size: 64, color: AppTheme.teal),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Queue Token',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'You currently do not have an active check-in. Check in from your appointments page when you arrive at the hospital.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalHeader(QueueProvider provider) {
    final queue = provider.activeQueueData!;
    final hospital = queue['hospitalId'] ?? {};
    final doctor = queue['doctorId'] ?? {};
    final dept = queue['departmentId'] ?? {};

    return GlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: AppTheme.teal, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital['name'] as String? ?? 'Government OPD Hospital',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  '${doctor['name'] ?? 'Doctor'} • ${dept['name'] ?? 'General OPD'}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalTokenCard(QueueProvider provider) {
    final queue = provider.activeQueueData!;
    final token = queue['tokenNumber'] as String? ?? 'A-000';

    return GlassHeroSurface(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      radius: 26,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Text(
              'YOUR DIGITAL QUEUE TOKEN',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              token,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: Text(
                'Status: ${queue['status'] ?? 'CHECKED_IN'}',
                style: const TextStyle(color: AppTheme.mint, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(QueueProvider provider) {
    final metrics = provider.activeMetrics ?? {};
    final currentToken = metrics['currentToken'] as String? ?? 'None';
    final patientsAhead = metrics['patientsAhead'] as int? ?? 0;
    final estWait = metrics['estimatedWaitMinutes'] as int? ?? 0;

    return Row(
      children: [
        Expanded(
          child: _metricBox('Now Serving', currentToken, Icons.notifications_active_rounded, AppTheme.sky),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox('Patients Ahead', '$patientsAhead', Icons.people_alt_rounded, const Color(0xFFD97706)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox('Est. Wait', '~${estWait}m', Icons.timer_rounded, AppTheme.teal),
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      radius: 18,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(QueueProvider provider) {
    final metrics = provider.activeMetrics ?? {};
    final isDelayed = metrics['isDelayed'] as bool? ?? false;
    final delayMsg = metrics['delayMessage'] as String? ?? '';
    final patientsAhead = metrics['patientsAhead'] as int? ?? 0;

    if (patientsAhead == 0 && (provider.activeQueueData?['status'] == 'CALLED')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.teal,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.teal.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'YOUR TURN! Please proceed to the consultation room.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (patientsAhead == 1) {
      return _tintedBanner(
        colour: const Color(0xFFD97706),
        icon: Icons.directions_walk_rounded,
        iconSize: 26,
        text: "You're Next! Please stay ready near the door.",
        fontSize: 14,
        bold: true,
      );
    }

    if (isDelayed) {
      return _tintedBanner(
        colour: const Color(0xFFDC2626),
        icon: Icons.warning_amber_rounded,
        iconSize: 24,
        text: delayMsg.isNotEmpty ? delayMsg : 'Possible delay detected in queue.',
        fontSize: 13,
        bold: false,
      );
    }

    return _tintedBanner(
      colour: AppTheme.teal,
      icon: Icons.check_circle_outline_rounded,
      iconSize: 20,
      text: 'Queue moving normally',
      fontSize: 13,
      bold: false,
    );
  }

  /// Status banner on tinted glass, so severity stays readable against the
  /// translucent backdrop.
  Widget _tintedBanner({
    required Color colour,
    required IconData icon,
    required double iconSize,
    required String text,
    required double fontSize,
    required bool bold,
  }) {
    return GlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 18,
      tint: colour,
      borderColor: colour.withValues(alpha: 0.45),
      child: Row(
        children: [
          Icon(icon, color: colour, size: iconSize),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colour,
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(QueueProvider provider) {
    final status = provider.activeQueueData?['status'] ?? 'CHECKED_IN';

    final steps = ['Booked', 'Checked In', 'Waiting', 'Your Turn', 'Completed'];
    int activeIndex = 1;
    if (status == 'WAITING') activeIndex = 2;
    if (status == 'CALLED' || status == 'IN_CONSULTATION') activeIndex = 3;
    if (status == 'COMPLETED') activeIndex = 4;

    return GlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Queue Journey',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isDone = index <= activeIndex;
              final isCurrent = index == activeIndex;

              return Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppTheme.sky.withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: isCurrent
                          ? AppTheme.sky
                          : isDone
                              ? AppTheme.teal
                              : Colors.white.withValues(alpha: 0.55),
                      child: isDone
                          ? Icon(
                              isCurrent ? Icons.play_arrow_rounded : Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            )
                          : const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppTheme.navy : AppTheme.textMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
