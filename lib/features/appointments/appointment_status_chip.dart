import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/appointment.dart';

/// Tinted glass pill telling the patient where an appointment stands.
///
/// Set [onDark] when the chip sits on a [GlassHeroSurface], so the label keeps
/// its meaning without disappearing into the navy.
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({
    super.key,
    required this.appointment,
    this.onDark = false,
  });
  final Appointment appointment;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    // (label, colour on light glass, colour on the dark hero)
    final (label, color, darkColor) = switch (appointment.status) {
      AppointmentStatus.cancelled => (
        'Cancelled',
        const Color(0xFFB3261E),
        const Color(0xFFFFA69C),
      ),
      AppointmentStatus.completed => (
        'Completed',
        const Color(0xFF4A6572),
        const Color(0xFFB9CDD4),
      ),
      AppointmentStatus.booked when appointment.isUpcoming => (
        'Upcoming',
        AppTheme.teal,
        AppTheme.mint,
      ),
      AppointmentStatus.booked => (
        'Past',
        const Color(0xFF4A6572),
        const Color(0xFFB9CDD4),
      ),
    };
    final accent = onDark ? darkColor : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: onDark ? 0.18 : 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
