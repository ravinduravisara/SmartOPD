import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/queue_service.dart';
import '../../widgets/glass.dart';

class StaffQueueConsoleScreen extends StatefulWidget {
  const StaffQueueConsoleScreen({required this.queueService, super.key});
  final QueueService queueService;

  @override
  State<StaffQueueConsoleScreen> createState() => _StaffQueueConsoleScreenState();
}

class _StaffQueueConsoleScreenState extends State<StaffQueueConsoleScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  Map<String, dynamic>? _currentlyServing;
  List<dynamic> _waitingList = [];
  List<dynamic> _completedList = [];
  List<dynamic> _skippedList = [];
  List<dynamic> _doctors = [];
  String? _selectedDoctorId; // null or 'all' for all doctors

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchQueueData();
    // Poll every 5 seconds for live queue updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchQueueData(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQueueData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await widget.queueService.getDoctorQueue(doctorId: _selectedDoctorId);
      if (!mounted) return;

      setState(() {
        _currentlyServing = res['currentlyServing'] as Map<String, dynamic>?;
        _waitingList = res['waitingList'] as List<dynamic>? ?? [];
        _completedList = res['completedList'] as List<dynamic>? ?? [];
        _skippedList = res['skippedList'] as List<dynamic>? ?? [];
        _doctors = res['doctors'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _callNextToken([String? specificQueueId]) async {
    setState(() => _actionLoading = true);
    try {
      final res = await widget.queueService.callNextToken(
        doctorId: _selectedDoctorId,
        queueId: specificQueueId,
      );
      if (!mounted) return;

      final calledToken = res['data']?['tokenNumber'] ?? 'Next Token';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📢 Token $calledToken has been called! Patient notified.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchQueueData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calling next patient: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeConsultation(String queueId) async {
    setState(() => _actionLoading = true);
    try {
      await widget.queueService.completeConsultation(queueId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Consultation completed successfully!'),
          backgroundColor: AppTheme.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchQueueData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing consultation: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _skipToken(String queueId) async {
    setState(() => _actionLoading = true);
    try {
      await widget.queueService.skipToken(queueId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏭️ Patient skipped from active queue.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fetchQueueData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error skipping patient: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      titleWidget: const Row(
        children: [
          Icon(Icons.dashboard_customize_rounded, color: AppTheme.teal, size: 22),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Doctor / Staff Queue Console',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navy),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.teal),
          tooltip: 'Refresh Queue',
          onPressed: () => _fetchQueueData(),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchQueueData(),
              edgeOffset: glassTopInset(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16 + glassTopInset(context), 16, 80),
                children: [
                  if (_error != null) ...[
                    GlassSurface(
                      padding: const EdgeInsets.all(14),
                      radius: 16,
                      tint: const Color(0xFFDC2626),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _buildDoctorFilter(),
                  const SizedBox(height: 16),
                  _buildCurrentlyServingCard(),
                  const SizedBox(height: 16),
                  _buildCallNextActionBar(),
                  const SizedBox(height: 24),
                  _buildWaitingQueueSection(),
                  const SizedBox(height: 24),
                  _buildCompletedAndSkippedSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildDoctorFilter() {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, color: AppTheme.teal, size: 20),
          const SizedBox(width: 10),
          const Text('Doctor:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navy)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDoctorId,
                hint: const Text('All Doctors (Entire OPD)'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Doctors (Entire OPD)', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ..._doctors.map((d) {
                    final dId = d['_id']?.toString() ?? '';
                    final name = d['name'] ?? 'Doctor';
                    final spec = d['specialization'] ?? '';
                    return DropdownMenuItem<String>(
                      value: dId,
                      child: Text('$name ($spec)', overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (newVal) {
                  setState(() => _selectedDoctorId = newVal);
                  _fetchQueueData();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyServingCard() {
    if (_currentlyServing == null) {
      return GlassSurface(
        padding: const EdgeInsets.all(20),
        radius: 20,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.meeting_room_outlined, color: Color(0xFFD97706), size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Patient In Consultation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "Call Next Patient" below to invite the next waiting token.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final queue = _currentlyServing!;
    final queueId = queue['_id']?.toString() ?? '';
    final token = queue['tokenNumber'] ?? 'A-000';
    final patient = queue['patientId'] as Map<String, dynamic>?;
    final patientName = patient?['name'] ?? 'Patient';
    final patientPhone = patient?['phone'] ?? 'N/A';
    final status = queue['status'] ?? 'CALLED';

    return GlassHeroSurface(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.mint.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: AppTheme.mint, size: 8),
                    SizedBox(width: 5),
                    Text(
                      'NOW SERVING IN ROOM',
                      style: TextStyle(color: AppTheme.mint, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Status: $status',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                token,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: $patientPhone',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Complete', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _actionLoading ? null : () => _completeConsultation(queueId),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 20),
                  label: const Text('Skip / Absent', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _actionLoading ? null : () => _skipToken(queueId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallNextActionBar() {
    final waitingCount = _waitingList.length;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 6,
        shadowColor: AppTheme.teal.withValues(alpha: 0.4),
      ),
      icon: _actionLoading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : const Icon(Icons.campaign_rounded, size: 26),
      label: Text(
        waitingCount > 0 ? '📢 Call Next Token ($waitingCount Waiting)' : '📢 Call Next Token (0 Waiting)',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      onPressed: _actionLoading || waitingCount == 0 ? null : () => _callNextToken(),
    );
  }

  Widget _buildWaitingQueueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Waiting Queue (${_waitingList.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_waitingList.isEmpty)
          GlassSurface(
            padding: const EdgeInsets.all(24),
            radius: 18,
            child: const Center(
              child: Text(
                'No patients currently waiting in line. All caught up! 🎉',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _waitingList.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _waitingList[index] as Map<String, dynamic>;
              final qId = item['_id']?.toString() ?? '';
              final token = item['tokenNumber'] ?? 'A-000';
              final patient = item['patientId'] as Map<String, dynamic>?;
              final pName = patient?['name'] ?? 'Patient';
              final pPhone = patient?['phone'] ?? '';
              final doc = item['doctorId'] as Map<String, dynamic>?;
              final dName = doc?['name'] ?? 'Doctor';

              return GlassSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                radius: 16,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.teal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.teal, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                token,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.navy, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dName ${pPhone.isNotEmpty ? "• $pPhone" : ""}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_rounded, color: AppTheme.teal),
                      tooltip: 'Call this token directly',
                      onPressed: _actionLoading ? null : () => _callNextToken(qId),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCompletedAndSkippedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: AppTheme.teal, size: 20),
            const SizedBox(width: 8),
            Text(
              'Today Summary: ${_completedList.length} Completed, ${_skippedList.length} Skipped',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navy),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GlassSurface(
                padding: const EdgeInsets.all(14),
                radius: 16,
                child: Column(
                  children: [
                    const Text('Completed Today', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '${_completedList.length}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassSurface(
                padding: const EdgeInsets.all(14),
                radius: 16,
                child: Column(
                  children: [
                    const Text('Skipped / No-Show', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '${_skippedList.length}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
