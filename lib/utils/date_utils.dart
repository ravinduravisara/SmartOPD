/// Date and time formatting for the booking screens. Written by hand so the
/// app does not need an extra localisation dependency.
class AppDates {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  static String month(DateTime date) => _months[date.month - 1];

  /// "12 Sep 2026"
  static String date(DateTime value) =>
      '${value.day} ${month(value)} ${value.year}';

  /// "Sat, 12 Sep"
  static String shortDate(DateTime value) =>
      '${weekday(value)}, ${value.day} ${month(value)}';

  /// "9:00 AM"
  static String time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "Sat, 12 Sep 2026 · 9:00 AM"
  static String dateTime(DateTime value) =>
      '${weekday(value)}, ${date(value)} · ${time(value)}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Today" / "Tomorrow" / "Sat, 12 Sep" for date strips and list headers.
  static String relativeDay(DateTime value) {
    final today = DateTime.now();
    if (isSameDay(value, today)) return 'Today';
    if (isSameDay(value, today.add(const Duration(days: 1)))) return 'Tomorrow';
    return shortDate(value);
  }

  /// Midnight on the given day, so date-only comparisons stay exact.
  static DateTime dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
