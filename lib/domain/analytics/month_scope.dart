import '../models/transaction_record.dart';

/// Works out which month the analytics pages are looking at.
///
/// [AnalyticsEngine] reports a single calendar month, taken from the anchor it
/// is given. Left to default to `DateTime.now()` it can only ever describe the
/// live month, so an imported statement covering an earlier period is stored
/// and listed but never counted. These helpers turn a chosen month into the
/// anchor the engine needs, and work out which months are worth offering.
abstract final class MonthScope {
  /// Normalises any date to the first instant of its month.
  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

  /// The anchor [AnalyticsEngine.compute] should be given for [month].
  ///
  /// The engine's daily series runs from the first of the month up to the
  /// anchor's day, so a month that is already over has to be anchored to its
  /// last day to be charted in full. The live month still stops at today,
  /// which keeps the chart from trailing off into days that have not happened.
  static DateTime anchorFor(DateTime month, {required DateTime now}) {
    if (month.year == now.year && month.month == now.month) return now;
    return lastDayOf(month);
  }

  /// The last day of [month]. Day zero of the next month is the last day of
  /// this one, which sidesteps leap years and 30/31 day months.
  static DateTime lastDayOf(DateTime month) => DateTime(month.year, month.month + 1, 0);

  /// Every month the user can step through, oldest first.
  ///
  /// The range is contiguous so the stepper never skips a gap, and always
  /// includes the live month even when the wallet is empty.
  static List<DateTime> availableMonths(
    List<TransactionRecord> transactions, {
    required DateTime now,
  }) {
    final DateTime live = monthOf(now);
    DateTime first = live;
    DateTime last = live;

    for (final TransactionRecord item in transactions) {
      final DateTime month = monthOf(item.date);
      if (month.isBefore(first)) first = month;
      if (month.isAfter(last)) last = month;
    }

    final List<DateTime> months = <DateTime>[];
    for (DateTime month = first; !month.isAfter(last); month = DateTime(month.year, month.month + 1)) {
      months.add(month);
    }
    return months;
  }

  /// The month to open on, given what the wallet holds.
  ///
  /// Landing on the live month is only useful when something happened in it.
  /// A statement is imported after its period closed, so an empty live month
  /// is the normal state right after an import and showing it would report
  /// zero for a wallet that is not empty. The newest month that actually holds
  /// data is the honest place to start; the selector still reaches the rest.
  ///
  /// Future-dated rows never win over a closed month — they are usually a
  /// mistyped year rather than the period the user wants to read.
  static DateTime initialMonth(
    List<TransactionRecord> transactions, {
    required DateTime now,
  }) {
    final DateTime live = monthOf(now);
    DateTime? upToLive;
    DateTime? earliest;

    for (final TransactionRecord item in transactions) {
      final DateTime month = monthOf(item.date);
      if (earliest == null || month.isBefore(earliest)) earliest = month;
      if (!month.isAfter(live) && (upToLive == null || month.isAfter(upToLive))) {
        upToLive = month;
      }
    }

    return upToLive ?? earliest ?? live;
  }

  /// Whether the stepper can move [offset] months from [month].
  ///
  /// Decided by the range's bounds rather than by whether [month] is itself in
  /// [months]. A selected month can fall outside the range — deleting its last
  /// transaction shrinks the range around it — and it still has to be able to
  /// step back in rather than stranding the user with both arrows dead.
  static bool canStep(DateTime month, int offset, List<DateTime> months) {
    if (months.isEmpty) return false;
    final DateTime target = DateTime(month.year, month.month + offset);
    return !target.isBefore(months.first) && !target.isAfter(months.last);
  }

  /// The month [transactions] mostly belong to, or null when there are none.
  ///
  /// Used to land the user on the period an import actually covers. Card
  /// statements run mid-month to mid-month, so a handful of rows spill into
  /// the next month; the bulk decides. Ties go to the more recent month.
  static DateTime? dominantMonth(List<TransactionRecord> transactions) {
    if (transactions.isEmpty) return null;

    final Map<DateTime, int> counts = <DateTime, int>{};
    for (final TransactionRecord item in transactions) {
      counts.update(monthOf(item.date), (int value) => value + 1, ifAbsent: () => 1);
    }

    DateTime? best;
    int bestCount = 0;
    for (final MapEntry<DateTime, int> entry in counts.entries) {
      if (best == null || entry.value > bestCount || (entry.value == bestCount && entry.key.isAfter(best))) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }
}
