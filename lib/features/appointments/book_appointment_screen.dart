import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/appointment.dart';
import '../../models/dependent.dart';
import '../../models/doctor.dart';
import '../../services/auth_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/glass.dart';

/// Picks a day and a free slot for a doctor. Used both to book a new
/// appointment and, when [reschedule] is set, to move an existing one.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({
    super.key,
    required this.service,
    this.doctor,
    this.doctorId,
    this.reschedule,
  }) : assert(
         doctor != null || doctorId != null,
         'Provide either a doctor or a doctorId',
       );

  final AuthService service;
  final Doctor? doctor;
  final String? doctorId;
  final Appointment? reschedule;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  static const _daysAhead = 21;

  final reason = TextEditingController();
  late Future<Doctor> doctorFuture;
  Future<List<DateTime>>? slots;
  Future<List<Dependent>>? dependents;

  DateTime selectedDay = AppDates.dayOnly(DateTime.now());
  DateTime? selectedSlot;
  String? dependentId;
  bool saving = false;
  String? error;

  bool get isReschedule => widget.reschedule != null;

  @override
  void initState() {
    super.initState();
    doctorFuture = widget.doctor != null
        ? Future.value(widget.doctor)
        : widget.service.getDoctor(widget.doctorId!);
    if (isReschedule) {
      selectedDay = AppDates.dayOnly(widget.reschedule!.scheduledAt);
    } else {
      dependents = widget.service.getDependents();
    }
    doctorFuture.then((doctor) {
      if (mounted) _loadSlots(doctor);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  void _loadSlots(Doctor doctor) => setState(() {
    selectedSlot = null;
    slots = widget.service.getDoctorSlots(
      doctor.id,
      selectedDay,
      excludeAppointmentId: widget.reschedule?.id,
    );
  });

  Future<void> _confirm(Doctor doctor) async {
    if (selectedSlot == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (isReschedule) {
        await widget.service.rescheduleAppointment(
          widget.reschedule!.id,
          selectedSlot!,
        );
      } else {
        await widget.service.bookAppointment(
          doctorId: doctor.id,
          scheduledAt: selectedSlot!,
          dependentId: dependentId,
          reason: reason.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isReschedule
                ? 'Appointment moved to ${AppDates.dateTime(selectedSlot!)}.'
                : 'Appointment confirmed for ${AppDates.dateTime(selectedSlot!)}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = '$exception';
        saving = false;
      });
      // The slot may have just been taken by someone else, so refresh.
      _loadSlots(doctor);
    }
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
    title: isReschedule ? 'Reschedule' : 'Book appointment',
    body: AsyncView<Doctor>(
      future: doctorFuture,
      builder: (context, doctor) => ListView(
        // Content scrolls behind the translucent app bar.
        padding: EdgeInsets.fromLTRB(20, 4 + glassTopInset(context), 20, 28),
        children: [
          // The doctor being booked is what the whole screen is about.
          GlassHeroSurface(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  doctor.subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                if (doctor.hospitalName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    doctor.hospitalName!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
          if (isReschedule) ...[
            const SizedBox(height: 14),
            GlassSurface(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Currently '
                      '${AppDates.dateTime(widget.reschedule!.scheduledAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text('Choose a day', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _DayStrip(
            days: _upcomingDays(),
            selected: selectedDay,
            onSelected: (day) {
              selectedDay = day;
              _loadSlots(doctor);
            },
          ),
          const SizedBox(height: 22),
          Text(
            'Available times',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          AsyncView<List<DateTime>>(
            future: slots,
            onRetry: () => _loadSlots(doctor),
            builder: (context, list) => list.isEmpty
                ? const EmptyView(
                    icon: Icons.event_busy_outlined,
                    message:
                        'No free slots on this day. Try another date from the '
                        'doctor\'s weekly schedule.',
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final slot in list)
                        ChoiceChip(
                          label: Text(AppDates.time(slot)),
                          selected: selectedSlot == slot,
                          onSelected: (_) =>
                              setState(() => selectedSlot = slot),
                        ),
                    ],
                  ),
          ),
          if (!isReschedule) ...[
            const SizedBox(height: 24),
            Text(
              'Who is this for?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _PatientPicker(
              dependents: dependents,
              selectedId: dependentId,
              onChanged: (value) => setState(() => dependentId = value),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: reason,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason for visit (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            ErrorView(message: error!),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: selectedSlot == null || saving
                  ? null
                  : () => _confirm(doctor),
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      selectedSlot == null
                          ? 'Select a time'
                          : isReschedule
                          ? 'Move to ${AppDates.time(selectedSlot!)}'
                          : 'Confirm ${AppDates.time(selectedSlot!)}',
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  List<DateTime> _upcomingDays() {
    final today = AppDates.dayOnly(DateTime.now());
    return List.generate(
      _daysAhead,
      (index) => today.add(Duration(days: index)),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.days,
    required this.selected,
    required this.onSelected,
  });
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 82,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final day = days[index];
        final isSelected = AppDates.isSameDay(day, selected);
        // Plain translucent tiles rather than GlassSurface: three weeks of
        // BackdropFilters in one scrolling strip is far too expensive.
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onSelected(day),
          child: Container(
            width: 68,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.teal : AppTheme.glassHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.teal : AppTheme.glassBorder,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.glassShadow,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppDates.weekday(day),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white70 : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.navy,
                  ),
                ),
                Text(
                  AppDates.month(day),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white70 : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// "Myself" plus any saved family members.
class _PatientPicker extends StatelessWidget {
  const _PatientPicker({
    required this.dependents,
    required this.selectedId,
    required this.onChanged,
  });
  final Future<List<Dependent>>? dependents;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Dependent>>(
    future: dependents,
    builder: (context, snapshot) {
      final list = snapshot.data ?? const <Dependent>[];
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          ChoiceChip(
            label: const Text('Myself'),
            selected: selectedId == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final dependent in list)
            ChoiceChip(
              label: Text('${dependent.name} (${dependent.relationship})'),
              selected: selectedId == dependent.id,
              onSelected: (_) => onChanged(dependent.id),
            ),
        ],
      );
    },
  );
}
