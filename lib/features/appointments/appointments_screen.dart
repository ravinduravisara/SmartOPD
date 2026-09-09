import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/appointment.dart';
import '../../services/auth_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_widget.dart';
import 'appointment_details_screen.dart';
import 'appointment_status_chip.dart';

/// Upcoming visits and full appointment history.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.service});
  final AuthService service;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  Future<List<Appointment>>? upcoming;
  Future<List<Appointment>>? history;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    upcoming = widget.service.getAppointments(scope: 'upcoming');
    history = widget.service.getAppointments(scope: 'past');
  });

  Future<void> _openDetails(Appointment appointment) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentDetailsScreen(
          service: widget.service,
          appointment: appointment,
        ),
      ),
    );
    if (updated == true) {
      changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(changed);
    },
    child: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My appointments'),
          bottom: const TabBar(
            labelColor: AppTheme.teal,
            indicatorColor: AppTheme.teal,
            tabs: [Tab(text: 'Upcoming'), Tab(text: 'History')],
          ),
        ),
        body: TabBarView(
          children: [
            _AppointmentList(
              future: upcoming,
              emptyMessage: 'No upcoming appointments. Book a visit to get started.',
              onRetry: _load,
              onRefresh: _load,
              onTap: _openDetails,
            ),
            _AppointmentList(
              future: history,
              emptyMessage: 'Your past and cancelled appointments will appear here.',
              onRetry: _load,
              onRefresh: _load,
              onTap: _openDetails,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AppointmentList extends StatelessWidget {
  const _AppointmentList({
    required this.future,
    required this.emptyMessage,
    required this.onRetry,
    required this.onRefresh,
    required this.onTap,
  });

  final Future<List<Appointment>>? future;
  final String emptyMessage;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;
  final ValueChanged<Appointment> onTap;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => onRefresh(),
    child: AsyncView<List<Appointment>>(
      future: future,
      onRetry: onRetry,
      builder: (context, list) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          if (list.isEmpty)
            EmptyView(
              icon: Icons.event_note_outlined,
              message: emptyMessage,
            ),
          for (final appointment in list) ...[
            AppointmentCard(
              appointment: appointment,
              onTap: () => onTap(appointment),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.doctorName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                AppointmentStatusChip(appointment: appointment),
              ],
            ),
            const SizedBox(height: 6),
            if (appointment.doctorSpecialization != null)
              Text(
                appointment.doctorSpecialization!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: AppTheme.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppDates.dateTime(appointment.scheduledAt),
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (appointment.hospitalName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    size: 16,
                    color: AppTheme.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      appointment.hospitalName!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (appointment.dependentName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppTheme.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For ${appointment.dependentName}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
