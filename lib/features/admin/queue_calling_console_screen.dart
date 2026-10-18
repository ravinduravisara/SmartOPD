import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/queue_service.dart';
import '../../widgets/glass.dart';
import '../../widgets/loading.dart';
import 'data/catalog_models.dart';
import 'data/catalog_service.dart';

class QueueCallingConsoleScreen extends StatefulWidget {
  const QueueCallingConsoleScreen({
    required this.queueService,
    this.catalogService,
    super.key,
  });

  final QueueService queueService;
  final AdminCatalogService? catalogService;

  @override
  State<QueueCallingConsoleScreen> createState() => _QueueCallingConsoleScreenState();
}

class _QueueCallingConsoleScreenState extends State<QueueCallingConsoleScreen> {
  bool _loading = true;
  bool _actionInProgress = false;
  String? _selectedDoctorId; // null = 'all'
  List<AdminDoctor> _doctors = [];

  Map<String, dynamic>? _current;
  List<dynamic> _waiting = [];
  List<dynamic> _completed = [];
  int _totalWaiting = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    // Auto-refresh every 8 seconds for real-time visibility
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_actionInProgress) {
        _fetchQueue(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchDoctors(),
      _fetchQueue(silent: true),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchDoctors() async {
    if (widget.catalogService == null) return;
    try {
      final list = await widget.catalogService!.doctors();
      if (mounted) {
        setState(() => _doctors = list);
      }
    } catch (_) {
      // Catalog doctors fallback
    }
  }

  Future<void> _fetchQueue({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final data = await widget.queueService.getDoctorQueue(
        doctorId: _selectedDoctorId,
      );
      if (!mounted) return;
      setState(() {
        _current = data['current'] as Map<String, dynamic>?;
        _waiting = data['waiting'] as List<dynamic>? ?? [];
        _completed = data['completed'] as List<dynamic>? ?? [];
        _totalWaiting = data['totalWaiting'] as int? ?? _waiting.length;
      });
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load queue: $e')),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _callNext({String? specificQueueId}) async {
    setState(() => _actionInProgress = true);
    try {
      final res = await widget.queueService.callNextToken(
        doctorId: _selectedDoctorId,
        queueId: specificQueueId,
      );
      if (!mounted) return;
      final token = res['data']?['tokenNumber'] ?? 'Next';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.teal,
          content: Text('📢 Token $token has been called! Patient notified.'),
        ),
      );
      await _fetchQueue(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _complete(String queueId, String tokenNumber) async {
    setState(() => _actionInProgress = true);
    try {
      await widget.queueService.completeConsultation(queueId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.mint,
          content: Text('✅ Token $tokenNumber marked as completed.'),
        ),
      );
      await _fetchQueue(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing consultation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _skip(String queueId, String tokenNumber) async {
    setState(() => _actionInProgress = true);
    try {
      await widget.queueService.skipToken(queueId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text('⏭️ Token $tokenNumber was skipped.'),
        ),
      );
      await _fetchQueue(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error skipping: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _noShow(String queueId, String tokenNumber) async {
    setState(() => _actionInProgress = true);
    try {
      await widget.queueService.markNoShow(queueId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.grey.shade700,
          content: Text('🚫 Token $tokenNumber marked as No-Show.'),
        ),
      );
      await _fetchQueue(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      titleWidget: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Doctor Calling Console',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          SizedBox(height: 1),
          Text(
            'Real-Time OPD Token Management',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.teal),
          tooltip: 'Refresh Queue',
          onPressed: _actionInProgress ? null : () => _fetchQueue(),
        ),
        const SizedBox(width: 8),
      ],
      body: _loading
          ? const Center(child: LoadingView())
          : RefreshIndicator(
              onRefresh: () => _fetchQueue(),
              color: AppTheme.teal,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16 + glassTopInset(context),
                  16,
                  40,
                ),
                children: [
                  // Filter by Doctor Bar
                  _doctorFilterBar(),
                  const SizedBox(height: 16),

                  // Currently Serving Hero Card
                  _currentServingCard(),
                  const SizedBox(height: 16),

                  // Primary Call Next Button
                  _callNextActionBar(),
                  const SizedBox(height: 24),

                  // Waiting Queue Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 20, color: AppTheme.navy),
                          const SizedBox(width: 8),
                          Text(
                            'Waiting in Queue',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_totalWaiting waiting',
                          style: const TextStyle(
                            color: AppTheme.teal,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Waiting Patients List
                  if (_waiting.isEmpty)
                    _emptyWaitingCard()
                  else
                    ..._waiting.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value as Map<String, dynamic>;
                      return _waitingPatientTile(idx + 1, item);
                    }),

                  const SizedBox(height: 24),

                  // Completed Today Header
                  if (_completed.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.mint),
                        const SizedBox(width: 8),
                        Text(
                          'Completed Today (${_completed.length})',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._completed.map((item) => _completedTile(item as Map<String, dynamic>)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _doctorFilterBar() {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 16,
      child: Row(
        children: [
          const Icon(Icons.medical_services_outlined, size: 20, color: AppTheme.teal),
          const SizedBox(width: 10),
          const Text(
            'Doctor:',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.navy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedDoctorId,
                isExpanded: true,
                hint: const Text('All Doctors / OPD Desks', style: TextStyle(fontSize: 13)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Doctors / OPD Desks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  ..._doctors.map(
                    (doc) => DropdownMenuItem<String?>(
                      value: doc.id,
                      child: Text(
                        '${doc.name} (${doc.specialization.isNotEmpty ? doc.specialization : 'OPD'})',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedDoctorId = val);
                  _fetchQueue();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentServingCard() {
    if (_current == null) {
      return GlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        radius: 20,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.meeting_room_outlined, size: 36, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 10),
            const Text(
              'No Token Currently in Consultation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
            ),
            const SizedBox(height: 4),
            const Text(
              'Click "Call Next Patient" below to call the next waiting token.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final token = _current!['tokenNumber'] as String? ?? 'N/A';
    final patient = _current!['patientId'] as Map<String, dynamic>?;
    final patientName = patient?['name'] as String? ?? 'Patient';
    final doctor = _current!['doctorId'] as Map<String, dynamic>?;
    final doctorName = doctor?['name'] as String? ?? 'Assigned Doctor';
    final room = doctor?['roomNumber'] as String? ?? 'OPD Room 1';
    final queueId = _current!['_id']?.toString() ?? '';
    final status = _current!['status'] as String? ?? 'CALLED';

    return GlassHeroSurface(
      padding: const EdgeInsets.all(20),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5FE0B1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status == 'IN_CONSULTATION' ? 'IN CONSULTATION' : 'NOW CALLING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                room,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Token',
                style: TextStyle(color: Color(0xCCD9F2EE), fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                token,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Patient: $patientName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Doctor: $doctorName',
            style: const TextStyle(
              color: Color(0xCCD9F2EE),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Action buttons for currently called patient
          Row(
            children: [
              Expanded(
                flex: 4,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _actionInProgress ? null : () => _complete(queueId, token),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'Complete',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _actionInProgress ? null : () => _skip(queueId, token),
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('Skip', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
                tooltip: 'Mark No-Show',
                onPressed: _actionInProgress ? null : () => _noShow(queueId, token),
                icon: const Icon(Icons.person_off_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _callNextActionBar() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.teal,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _actionInProgress || _waiting.isEmpty ? null : () => _callNext(),
        icon: _actionInProgress
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.campaign_rounded, size: 24),
        label: Text(
          _waiting.isEmpty
              ? 'No Waiting Patients'
              : 'Call Next Patient (${_waiting.first['tokenNumber'] ?? ''})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }

  Widget _emptyWaitingCard() {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      radius: 18,
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 40, color: AppTheme.teal.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            const Text(
              'Queue is Clear!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
            ),
            const SizedBox(height: 4),
            const Text(
              'No patients currently waiting in this queue.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waitingPatientTile(int rank, Map<String, dynamic> item) {
    final token = item['tokenNumber'] as String? ?? 'N/A';
    final patient = item['patientId'] as Map<String, dynamic>?;
    final patientName = patient?['name'] as String? ?? 'Patient';
    final doctor = item['doctorId'] as Map<String, dynamic>?;
    final doctorName = doctor?['name'] as String? ?? 'Doctor';
    final queueId = item['_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        radius: 16,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppTheme.teal,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.navy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          token,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Assigned to: $doctorName',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _actionInProgress ? null : () => _callNext(specificQueueId: queueId),
              child: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completedTile(Map<String, dynamic> item) {
    final token = item['tokenNumber'] as String? ?? 'N/A';
    final patient = item['patientId'] as Map<String, dynamic>?;
    final patientName = patient?['name'] as String? ?? 'Patient';
    final status = item['status'] as String? ?? 'COMPLETED';

    Color statusColor;
    String statusLabel;
    if (status == 'COMPLETED') {
      statusColor = AppTheme.mint;
      statusLabel = 'Completed';
    } else if (status == 'SKIPPED') {
      statusColor = Colors.orange;
      statusLabel = 'Skipped';
    } else {
      statusColor = Colors.grey;
      statusLabel = 'No-show';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Text(
            token,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.navy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              patientName,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.navy),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
