import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/doctor.dart';
import '../../services/auth_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_widget.dart';
import 'doctor_details_screen.dart';

/// Doctor list. Shows every doctor by default, or only those in one hospital
/// or department when those ids are supplied.
class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({
    super.key,
    required this.service,
    this.title = 'Doctors',
    this.hospitalId,
    this.departmentId,
  });

  final AuthService service;
  final String title;
  final String? hospitalId;
  final String? departmentId;

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final search = TextEditingController();
  late Future<List<Doctor>> doctors;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _load() => setState(() {
    doctors = widget.service.getDoctors(
      hospitalId: widget.hospitalId,
      departmentId: widget.departmentId,
      query: search.text,
    );
  });

  /// Passes a completed booking back up so the home screen can refresh.
  Future<void> _openDoctor(String doctorId) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            DoctorDetailsScreen(service: widget.service, doctorId: doctorId),
      ),
    );
    if (booked == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search name or specialization',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: _load,
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            child: AsyncView<List<Doctor>>(
              future: doctors,
              onRetry: _load,
              builder: (context, list) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  if (list.isEmpty)
                    const EmptyView(
                      icon: Icons.person_search_outlined,
                      message: 'No doctors matched your search.',
                    ),
                  for (final doctor in list) ...[
                    DoctorCard(
                      doctor: doctor,
                      onTap: () => _openDoctor(doctor.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, required this.onTap});
  final Doctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.mint,
              child: Text(
                doctor.name.replaceFirst('Dr. ', '').characters.first
                    .toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialization,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (doctor.hospitalName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      doctor.hospitalName!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Pill(
                        icon: Icons.workspace_premium_outlined,
                        label: '${doctor.experienceYears} yrs',
                      ),
                      _Pill(
                        icon: Icons.payments_outlined,
                        label: 'Rs. ${doctor.consultationFee}',
                      ),
                      if (doctor.schedule.isNotEmpty)
                        _Pill(
                          icon: Icons.event_available_outlined,
                          label:
                              '${doctor.schedule.length} '
                              '${doctor.schedule.length == 1 ? 'session' : 'sessions'}/week',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF6F4),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.teal),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
