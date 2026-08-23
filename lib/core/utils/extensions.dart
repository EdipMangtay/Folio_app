extension DateOnlyComparison on DateTime {
  bool isSameDay(DateTime other) => year == other.year && month == other.month && day == other.day;
  bool isSameMonth(DateTime other) => year == other.year && month == other.month;
}
