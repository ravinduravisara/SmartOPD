import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/doctor.dart';
import '../../services/auth_service.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glass.dart';
import '../appointments/book_appointment_screen.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({
    super.key,
    required this.service,
    required this.doctorId,
  });
  final AuthService service;
  final String doctorId;

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  late Future<Doctor> doctor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    doctor = widget.service.getDoctor(widget.doctorId);
  });

  Future<void> _book(Doctor value) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            BookAppointmentScreen(service: widget.service, doctor: value),
      ),
    );
    if (booked == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
    title: 'Doctor',
    body: AsyncView<Doctor>(
      future: doctor,
      onRetry: _load,
      builder: (context, data) => ListView(
        // Extra top padding so the list clears the translucent app bar.
        padding: EdgeInsets.fromLTRB(20, glassTopInset(context) + 4, 20, 28),
        children: [
          // The focal card on this screen: dark glass, light type.
          GlassHeroSurface(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.mint.withValues(alpha: 0.9),
                  child: Text(
                    data.name.replaceFirst('Dr. ', '').characters.first
                        .toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.specialization,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.mint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (data.qualifications != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          data.qualifications!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFFBBD2D6)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassSurface(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Stat(
                  label: 'Experience',
                  value: '${data.experienceYears} yrs',
                ),
                _Stat(label: 'Fee', value: 'Rs. ${data.consultationFee}'),
                _Stat(label: 'Slot', value: '${data.slotMinutes} min'),
              ],
            ),
          ),
          if (data.hospitalName != null) ...[
            const SizedBox(height: 20),
            Text('Location', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              [
                data.hospitalName,
                if (data.departmentName != null) data.departmentName,
                if (data.hospitalCity != null) data.hospitalCity,
              ].whereType<String>().join(' · '),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          if (data.about != null) ...[
            const SizedBox(height: 20),
            Text('About', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(data.about!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 22),
          Text(
            'Weekly availability',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (data.schedule.isEmpty)
            Text(
              'This doctor has no clinic sessions scheduled.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            GlassSurface(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              child: Column(
                children: [
                  for (final block in data.schedule)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.mint.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              size: 18,
                              color: AppTheme.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              block.day,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            block.label,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 26),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: data.schedule.isEmpty ? null : () => _book(data),
              icon: const Icon(Icons.calendar_month_rounded),
              label: const Text('Book appointment'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
