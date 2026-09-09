import 'package:flutter/material.dart';

import '../../models/appointment.dart';

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (appointment.status) {
      AppointmentStatus.cancelled => ('Cancelled', const Color(0xFFB3261E)),
      AppointmentStatus.completed => ('Completed', const Color(0xFF4A6572)),
      AppointmentStatus.booked when appointment.isUpcoming => (
        'Upcoming',
        const Color(0xFF007F73),
      ),
      AppointmentStatus.booked => ('Past', const Color(0xFF4A6572)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
