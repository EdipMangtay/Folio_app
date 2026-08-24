import '../models/subscription_record.dart';
import '../models/transaction_record.dart';

/// Derives recurring charges from the transactions the user actually has.
///
/// Subscriptions used to be a fixed demo list, which meant the screen showed
/// the same four services no matter what was imported. They are now computed,
/// so the list reflects the real statement.
abstract final class SubscriptionDetector {
  static const int _minimumCharges = 3;
  static const int _lookbackDays = 400;

  /// A charge older than this means the subscription is probably cancelled.
  static const int _staleAfterDays = 50;

  static List<SubscriptionRecord> detect(
    List<TransactionRecord> transactions, {
    DateTime? now,
  }) {
    final DateTime anchor = now ?? DateTime.now();
    final DateTime windowStart = anchor.subtract(const Duration(days: _lookbackDays));

    final Map<String, List<TransactionRecord>> byMerchant = <String, List<TransactionRecord>>{};
    for (final TransactionRecord record in transactions) {
      if (!record.isExpense) continue;
      if (record.date.isBefore(windowStart)) continue;
      if (record.date.isAfter(anchor)) continue;
      final String name = (record.merchant ?? record.title).trim();
      if (name.isEmpty) continue;
      byMerchant.putIfAbsent(name.toLowerCase(), () => <TransactionRecord>[]).add(record);
    }

    final List<SubscriptionRecord> detected = <SubscriptionRecord>[];
    for (final MapEntry<String, List<TransactionRecord>> entry in byMerchant.entries) {
      final SubscriptionRecord? candidate = _evaluate(entry.value, anchor);
      if (candidate != null) detected.add(candidate);
    }

    detected.sort(
      (SubscriptionRecord a, SubscriptionRecord b) => b.monthlyAmount.compareTo(a.monthlyAmount),
    );
    return detected;
  }

  static SubscriptionRecord? _evaluate(List<TransactionRecord> charges, DateTime anchor) {
    if (charges.length < _minimumCharges) return null;

    final List<TransactionRecord> sorted = List<TransactionRecord>.from(charges)
      ..sort((TransactionRecord a, TransactionRecord b) => a.date.compareTo(b.date));

    final TransactionRecord latest = sorted.last;
    if (anchor.difference(latest.date).inDays > _staleAfterDays) return null;

    // Monthly cadence: every gap between consecutive charges must sit around
    // one month. A merchant visited twice a week never qualifies.
    for (int i = 1; i < sorted.length; i++) {
      final int gap = sorted[i].date.difference(sorted[i - 1].date).inDays;
      if (gap < 20 || gap > 45) return null;
    }

    final List<double> amounts =
        sorted.map((TransactionRecord item) => item.amount).toList(growable: false);
    final double highest = amounts.reduce((double a, double b) => a > b ? a : b);
    final double lowest = amounts.reduce((double a, double b) => a < b ? a : b);
    if (highest <= 0) return null;
    // Price hikes happen, but a subscription does not swing wildly month to month.
    if ((highest - lowest) / highest > 0.35) return null;

    final double average =
        amounts.fold<double>(0, (double sum, double value) => sum + value) / amounts.length;

    return SubscriptionRecord(
      id: 'sub_${latest.merchant ?? latest.title}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_'),
      merchant: latest.merchant ?? latest.title,
      category: latest.category,
      monthlyAmount: double.parse(average.toStringAsFixed(2)),
      nextBillingDate: _nextBilling(latest.date),
    );
  }

  static DateTime _nextBilling(DateTime last) {
    final int targetMonth = last.month + 1;
    final int year = last.year + (targetMonth > 12 ? 1 : 0);
    final int month = targetMonth > 12 ? targetMonth - 12 : targetMonth;
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, last.day > daysInMonth ? daysInMonth : last.day);
  }
}
