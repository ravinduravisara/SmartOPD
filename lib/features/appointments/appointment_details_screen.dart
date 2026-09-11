import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/appointment.dart';
import '../../services/auth_service.dart';
import '../../services/queue_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/error_widget.dart';
import '../queue/queue_provider.dart';
import '../queue/queue_screen.dart';
import 'appointment_status_chip.dart';
import 'book_appointment_screen.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  const AppointmentDetailsScreen({
    super.key,
    required this.service,
    required this.appointment,
    this.queueProvider,
  });
  final AuthService service;
  final Appointment appointment;
  final QueueProvider? queueProvider;

  @override
  State<AppointmentDetailsScreen> createState() =>
      _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late Appointment appointment = widget.appointment;
  bool changed = false;
  bool working = false;
  String? error;

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          'Your ${AppDates.dateTime(appointment.scheduledAt)} appointment with '
          '${appointment.doctorName} will be cancelled and the slot released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      final updated = await widget.service.cancelAppointment(appointment.id);
      if (!mounted) return;
      setState(() {
        appointment = updated;
        changed = true;
        working = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled.')),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = '$exception';
        working = false;
      });
    }
  }

  Future<void> _reschedule() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          service: widget.service,
          doctorId: appointment.doctorId,
          reschedule: appointment,
        ),
      ),
    );
    if (done != true || !mounted) return;
    changed = true;
    try {
      final refreshed = await widget.service.getAppointments(scope: 'upcoming');
      if (!mounted) return;
      setState(() {
        appointment = refreshed.firstWhere(
          (item) => item.id == appointment.id,
          orElse: () => appointment,
        );
      });
    } catch (_) {
      // The change was saved; the list screen reloads on the way back.
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(changed);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appointment.doctorName,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              AppointmentStatusChip(appointment: appointment),
            ],
          ),
          if (appointment.doctorSpecialization != null) ...[
            const SizedBox(height: 6),
            Text(
              appointment.doctorSpecialization!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.event_rounded,
                    label: 'When',
                    value: AppDates.dateTime(appointment.scheduledAt),
                  ),
                  _DetailRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Duration',
                    value: '${appointment.durationMinutes} minutes',
                  ),
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Patient',
                    value: appointment.dependentRelationship == null
                        ? appointment.patientLabel
                        : '${appointment.patientLabel} '
                              '(${appointment.dependentRelationship})',
                  ),
                  if (appointment.departmentName != null)
                    _DetailRow(
                      icon: Icons.medical_services_outlined,
                      label: 'Department',
                      value: appointment.departmentName!,
                    ),
                  if (appointment.hospitalName != null)
                    _DetailRow(
                      icon: Icons.local_hospital_outlined,
                      label: 'Hospital',
                      value: [
                        appointment.hospitalName,
                        appointment.hospitalAddress,
                      ].whereType<String>().join('\n'),
                    ),
                  if (appointment.hospitalPhone != null)
                    _DetailRow(
                      icon: Icons.call_outlined,
                      label: 'Contact',
                      value: appointment.hospitalPhone!,
                    ),
                  if (appointment.consultationFee > 0)
                    _DetailRow(
                      icon: Icons.payments_outlined,
                      label: 'Fee',
                      value: 'Rs. ${appointment.consultationFee}',
                    ),
                  if (appointment.reason != null &&
                      appointment.reason!.isNotEmpty)
                    _DetailRow(
                      icon: Icons.notes_rounded,
                      label: 'Reason',
                      value: appointment.reason!,
                    ),
                  if (appointment.rescheduledFrom != null)
                    _DetailRow(
                      icon: Icons.history_rounded,
                      label: 'Moved from',
                      value: AppDates.dateTime(appointment.rescheduledFrom!),
                    ),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            ErrorView(message: error!),
          ],
          const SizedBox(height: 22),
          if (appointment.status == AppointmentStatus.booked) ...[
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                onPressed: working
                    ? null
                    : () async {
                        setState(() => working = true);
                        try {
                          final navigator = Navigator.of(context);
                          final qp = widget.queueProvider ?? QueueProvider(QueueService(widget.service.api));
                          final success = await qp.checkIn(appointment.id);
                          if (mounted) {
                            setState(() {
                              working = false;
                              changed = true;
                            });
                            if (success) {
                              navigator.push(
                                MaterialPageRoute(builder: (_) => QueueScreen(provider: qp)),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) setState(() { working = false; error = '$e'; });
                        }
                      },
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Check In & Get Live Token', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (appointment.canModify) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: working ? null : _reschedule,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Reschedule'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: working ? null : _cancel,
                icon: working
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('Cancel appointment'),
              ),
            ),
          ] else
            Text(
              appointment.status == AppointmentStatus.cancelled
                  ? 'This appointment was cancelled.'
                  : 'This appointment has already passed.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.teal),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
