import 'package:flutter/material.dart';
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

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            title: Row(
              children: [
                const Text(
                  'Live Queue Status',
                  style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.smart_toy_rounded, color: Color(0xFF0284C7)),
                tooltip: 'Queue AI Assistant',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SmartQueueAssistantScreen(provider: provider)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Color(0xFF475569)),
                tooltip: 'Queue History',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => QueueHistoryScreen(provider: provider)),
                  );
                },
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.activeQueueData == null
                  ? _buildEmptyState(context)
                  : RefreshIndicator(
                      onRefresh: () => provider.fetchActiveQueue(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_outlined, size: 64, color: Color(0xFF0284C7)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Queue Token',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You currently do not have an active check-in. Check in from your appointments page when you arrive at the hospital.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF0D9488), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital['name'] as String? ?? 'Government OPD Hospital',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${doctor['name'] ?? 'Doctor'} • ${dept['name'] ?? 'General OPD'}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'YOUR DIGITAL QUEUE TOKEN',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Status: ${queue['status'] ?? 'CHECKED_IN'}',
              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
          child: _metricBox('Now Serving', currentToken, Icons.notifications_active_rounded, const Color(0xFF0284C7)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox('Patients Ahead', '$patientsAhead', Icons.people_alt_rounded, const Color(0xFFD97706)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox('Est. Wait', '~${estWait}m', Icons.timer_rounded, const Color(0xFF059669)),
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(16),
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
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.directions_walk_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "You're Next! Please stay ready near the door.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (isDelayed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                delayMsg.isNotEmpty ? delayMsg : 'Possible delay detected in queue.',
                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
          SizedBox(width: 10),
          Text(
            'Queue moving normally',
            style: TextStyle(color: Color(0xFF15803D), fontSize: 13, fontWeight: FontWeight.w600),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Queue Journey',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isDone = index <= activeIndex;
              final isCurrent = index == activeIndex;

              return Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isCurrent
                        ? const Color(0xFF0284C7)
                        : isDone
                            ? const Color(0xFF10B981)
                            : const Color(0xFFE2E8F0),
                    child: isDone
                        ? Icon(
                            isCurrent ? Icons.play_arrow_rounded : Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? const Color(0xFF0284C7) : const Color(0xFF64748B),
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
