import '../models/transaction_record.dart';

class DaySpendPoint {
  const DaySpendPoint({
    required this.date,
    required this.weekdayName,
    required this.amount,
  });

  final DateTime date;
  final String weekdayName;
  final double amount;
}

class WeeklyAnalytics {
  const WeeklyAnalytics({
    required this.weekExpense,
    required this.weekIncome,
    required this.previousWeekExpense,
    required this.changePercent,
    required this.savings,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.topMerchant,
    required this.topMerchantAmount,
    required this.topTransaction,
    required this.dailyAverage,
    required this.busiestDay,
    required this.categoryTotals,
    required this.dailySeries,
    required this.summaryHeadline,
    required this.summaryMessage,
  });

  final double weekExpense;
  final double weekIncome;
  final double previousWeekExpense;
  final double changePercent;
  final double savings;
  final String topCategory;
  final double topCategoryAmount;
  final String topMerchant;
  final double topMerchantAmount;
  final TransactionRecord? topTransaction;
  final double dailyAverage;
  final String busiestDay;
  final Map<String, double> categoryTotals;
  final List<DaySpendPoint> dailySeries;
  final String summaryHeadline;
  final String summaryMessage;

  bool get hasExpense => weekExpense > 0;
  bool get isFrugal => changePercent < -5;
  bool get isAccelerated => changePercent > 10;
}

abstract final class WeeklyAnalyticsEngine {
  static const List<String> _weekdayNames = <String>[
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
  ];

  static const List<String> _fullWeekdayNames = <String>[
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
  ];

  /// Computes weekly analytics for the 7-day period ending on [anchor] (or the current week).
  static WeeklyAnalytics compute(
    List<TransactionRecord> transactions, {
    DateTime? now,
  }) {
    final DateTime anchor = now ?? DateTime.now();
    final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);

    // Calculate Monday of the current week
    final int currentWeekday = today.weekday; // 1 = Monday, 7 = Sunday
    final DateTime currentWeekStart = today.subtract(Duration(days: currentWeekday - 1));
    final DateTime currentWeekEnd = currentWeekStart.add(const Duration(days: 7));

    // Previous week Monday to Sunday
    final DateTime prevWeekStart = currentWeekStart.subtract(const Duration(days: 7));
    final DateTime prevWeekEnd = currentWeekStart;

    final Iterable<TransactionRecord> thisWeekTxns = transactions.where(
      (TransactionRecord item) =>
          !item.date.isBefore(currentWeekStart) && item.date.isBefore(currentWeekEnd),
    );

    final Iterable<TransactionRecord> prevWeekTxns = transactions.where(
      (TransactionRecord item) =>
          !item.date.isBefore(prevWeekStart) && item.date.isBefore(prevWeekEnd),
    );

    final double weekExpense = _sum(
      thisWeekTxns.where((TransactionRecord item) => item.isExpense).map((TransactionRecord item) => item.amount),
    );
    final double weekIncome = _sum(
      thisWeekTxns.where((TransactionRecord item) => item.isIncome).map((TransactionRecord item) => item.amount),
    );
    final double prevWeekExpense = _sum(
      prevWeekTxns.where((TransactionRecord item) => item.isExpense).map((TransactionRecord item) => item.amount),
    );

    final double changePercent = prevWeekExpense == 0
        ? 0
        : ((weekExpense - prevWeekExpense) / prevWeekExpense) * 100;
    final double savings = weekIncome - weekExpense;

    // Category and merchant totals
    final Map<String, double> categoryTotals = <String, double>{};
    final Map<String, double> merchantTotals = <String, double>{};
    final Map<int, double> weekdayExpenses = <int, double>{};

    TransactionRecord? largestExpense;

    for (final TransactionRecord item in thisWeekTxns.where((TransactionRecord item) => item.isExpense)) {
      categoryTotals.update(item.category, (double v) => v + item.amount, ifAbsent: () => item.amount);
      final String merchant = item.merchant ?? item.title;
      merchantTotals.update(merchant, (double v) => v + item.amount, ifAbsent: () => item.amount);
      weekdayExpenses.update(item.date.weekday, (double v) => v + item.amount, ifAbsent: () => item.amount);

      if (largestExpense == null || item.amount > largestExpense.amount) {
        largestExpense = item;
      }
    }

    // Top Category
    String topCategory = '—';
    double topCategoryAmount = 0;
    if (categoryTotals.isNotEmpty) {
      final List<MapEntry<String, double>> sorted = categoryTotals.entries.toList()
        ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));
      topCategory = sorted.first.key;
      topCategoryAmount = sorted.first.value;
    }

    // Top Merchant
    String topMerchant = '—';
    double topMerchantAmount = 0;
    if (merchantTotals.isNotEmpty) {
      final List<MapEntry<String, double>> sorted = merchantTotals.entries.toList()
        ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));
      topMerchant = sorted.first.key;
      topMerchantAmount = sorted.first.value;
    }

    // Daily series (Monday to Sunday)
    final List<DaySpendPoint> dailySeries = <DaySpendPoint>[];
    int busiestWeekday = 1;
    double maxDayExpense = -1;

    for (int i = 0; i < 7; i++) {
      final DateTime day = currentWeekStart.add(Duration(days: i));
      final double dayAmount = weekdayExpenses[day.weekday] ?? 0;
      dailySeries.add(
        DaySpendPoint(
          date: day,
          weekdayName: _weekdayNames[i],
          amount: dayAmount,
        ),
      );
      if (dayAmount > maxDayExpense) {
        maxDayExpense = dayAmount;
        busiestWeekday = day.weekday;
      }
    }

    final String busiestDay = maxDayExpense > 0 ? _fullWeekdayNames[busiestWeekday - 1] : '—';
    final int daysElapsed = today.difference(currentWeekStart).inDays + 1;
    final double dailyAverage = daysElapsed > 0 ? weekExpense / daysElapsed.clamp(1, 7) : 0;

    // Narrative generation
    final String headline;
    final String message;

    if (weekExpense == 0) {
      headline = 'Sakin Bir Hafta';
      message = 'Bu hafta henüz bir harcama kaydedilmedi. Bütçen tamamen korundu.';
    } else if (changePercent < -10) {
      headline = 'Tasarruflu Ritim 🌿';
      message = 'Önceki haftaya göre harcamalarını %${changePercent.abs().toStringAsFixed(0)} azalttın. Harika bir kontrol!';
    } else if (changePercent > 15) {
      headline = 'Hızlanmış Harcama';
      message = 'Bu hafta giderlerin geçen haftaya göre %${changePercent.toStringAsFixed(0)} daha yüksek seyrediyor.';
    } else {
      headline = 'Dengeli Seyir ⚖️';
      message = 'Harcama ritmin önceki haftayla oldukça paralel ve dengeli ilerliyor.';
    }

    return WeeklyAnalytics(
      weekExpense: weekExpense,
      weekIncome: weekIncome,
      previousWeekExpense: prevWeekExpense,
      changePercent: changePercent,
      savings: savings,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      topMerchant: topMerchant,
      topMerchantAmount: topMerchantAmount,
      topTransaction: largestExpense,
      dailyAverage: dailyAverage,
      busiestDay: busiestDay,
      categoryTotals: categoryTotals,
      dailySeries: dailySeries,
      summaryHeadline: headline,
      summaryMessage: message,
    );
  }

  static double _sum(Iterable<double> values) {
    double total = 0;
    for (final double value in values) {
      total += value;
    }
    return total;
  }
}
