import 'dart:math' as math;

import '../models/insight.dart';
import '../models/transaction_record.dart';

class DailySpendPoint {
  const DailySpendPoint(this.date, this.amount);
  final DateTime date;
  final double amount;
}

class WalletAnalytics {
  const WalletAnalytics({
    required this.monthExpense,
    required this.monthIncome,
    required this.previousMonthExpense,
    required this.changePercent,
    required this.savings,
    required this.savingsRate,
    required this.financialScore,
    required this.categoryTotals,
    required this.merchantTotals,
    required this.weekdayTotals,
    required this.dailySeries,
    required this.insights,
  });

  final double monthExpense;
  final double monthIncome;
  final double previousMonthExpense;
  final double changePercent;
  final double savings;
  final double savingsRate;
  final int financialScore;
  final Map<String, double> categoryTotals;
  final Map<String, double> merchantTotals;
  final Map<int, double> weekdayTotals;
  final List<DailySpendPoint> dailySeries;
  final List<Insight> insights;
}

abstract final class AnalyticsEngine {
  static WalletAnalytics compute(List<TransactionRecord> transactions, {DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    final DateTime currentStart = DateTime(anchor.year, anchor.month);
    final DateTime nextStart = DateTime(anchor.year, anchor.month + 1);
    final DateTime previousStart = DateTime(anchor.year, anchor.month - 1);

    final Iterable<TransactionRecord> current = transactions.where(
      (TransactionRecord item) => !item.date.isBefore(currentStart) && item.date.isBefore(nextStart),
    );
    final Iterable<TransactionRecord> previous = transactions.where(
      (TransactionRecord item) => !item.date.isBefore(previousStart) && item.date.isBefore(currentStart),
    );

    final double expense = _sum(
      current.where((TransactionRecord item) => item.isExpense).map((TransactionRecord item) => item.amount),
    );
    final double income = _sum(
      current.where((TransactionRecord item) => item.isIncome).map((TransactionRecord item) => item.amount),
    );
    final double previousExpense = _sum(
      previous.where((TransactionRecord item) => item.isExpense).map((TransactionRecord item) => item.amount),
    );
    final double change = previousExpense == 0 ? 0 : ((expense - previousExpense) / previousExpense) * 100;
    final double savings = income - expense;
    final double savingsRate = income <= 0 ? 0 : (savings / income) * 100;

    final Map<String, double> categoryTotals = <String, double>{};
    final Map<String, double> merchantTotals = <String, double>{};
    final Map<int, double> weekdayTotals = <int, double>{};
    final Map<DateTime, double> byDay = <DateTime, double>{};
    final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);

    for (final TransactionRecord item in current.where((TransactionRecord item) => item.isExpense)) {
      categoryTotals.update(item.category, (double value) => value + item.amount, ifAbsent: () => item.amount);
      final String merchant = item.merchant ?? item.title;
      merchantTotals.update(merchant, (double value) => value + item.amount, ifAbsent: () => item.amount);
      weekdayTotals.update(item.date.weekday, (double value) => value + item.amount, ifAbsent: () => item.amount);
      final DateTime day = DateTime(item.date.year, item.date.month, item.date.day);
      byDay.update(day, (double value) => value + item.amount, ifAbsent: () => item.amount);
    }

    final List<DailySpendPoint> daily = <DailySpendPoint>[];
    for (DateTime date = currentStart; !date.isAfter(today); date = DateTime(date.year, date.month, date.day + 1)) {
      daily.add(DailySpendPoint(date, byDay[date] ?? 0));
    }

    final int score = _score(
      savingsRate: savingsRate,
      changePercent: change,
      expense: expense,
      income: income,
    );

    return WalletAnalytics(
      monthExpense: expense,
      monthIncome: income,
      previousMonthExpense: previousExpense,
      changePercent: change,
      savings: savings,
      savingsRate: savingsRate,
      financialScore: score,
      categoryTotals: _sortMap(categoryTotals),
      merchantTotals: _sortMap(merchantTotals),
      weekdayTotals: weekdayTotals,
      dailySeries: daily,
      insights: _insights(
        categoryTotals: categoryTotals,
        changePercent: change,
        savingsRate: savingsRate,
        current: current.toList(growable: false),
      ),
    );
  }

  static double _sum(Iterable<double> values) => values.fold<double>(0, (double a, double b) => a + b);

  static Map<String, double> _sortMap(Map<String, double> source) {
    final List<MapEntry<String, double>> entries = source.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));
    return Map<String, double>.fromEntries(entries);
  }

  static int _score({
    required double savingsRate,
    required double changePercent,
    required double expense,
    required double income,
  }) {
    double value = 68;
    value += savingsRate.clamp(-20, 35) * 0.5;
    if (changePercent < 0) value += math.min(10, changePercent.abs() * 0.25);
    if (changePercent > 20) value -= math.min(12, (changePercent - 20) * 0.25);
    if (income > 0 && expense > income) value -= 12;
    return value.clamp(35, 96).round();
  }

  static List<Insight> _insights({
    required Map<String, double> categoryTotals,
    required double changePercent,
    required double savingsRate,
    required List<TransactionRecord> current,
  }) {
    final List<Insight> insights = <Insight>[];
    final List<MapEntry<String, double>> sorted = categoryTotals.entries.toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));

    if (changePercent.abs() >= 4) {
      insights.add(
        Insight(
          title: changePercent < 0 ? 'Harcama ritmin yavaşladı.' : 'Harcama ritmin hızlandı.',
          body: changePercent < 0
              ? 'Bu ay toplam giderin geçen aya göre daha düşük ilerliyor.'
              : 'Bu ay toplam giderin geçen ayın aynı döneminden daha yüksek.',
          metric: '${changePercent < 0 ? '−' : '+'}${changePercent.abs().toStringAsFixed(1).replaceAll('.', ',')}%',
          tone: changePercent < 0 ? InsightTone.positive : InsightTone.warning,
        ),
      );
    }

    if (sorted.isNotEmpty) {
      insights.add(
        Insight(
          title: '${sorted.first.key} en büyük payı alıyor.',
          body: 'Bu ayki harcamalarının en yüksek bölümü bu kategoride toplandı.',
          metric: '${sorted.first.value.round()} ₺',
          tone: InsightTone.neutral,
        ),
      );
    }

    final int smallCount = current.where((TransactionRecord item) => item.isExpense && item.amount < 300).length;
    final double smallTotal = _sum(
      current.where((TransactionRecord item) => item.isExpense && item.amount < 300).map((TransactionRecord item) => item.amount),
    );
    if (smallCount >= 4) {
      insights.add(
        Insight(
          title: 'Küçük işlemler birikiyor.',
          body: '$smallCount adet 300 ₺ altı işlem toplam giderinde görünür bir pay oluşturuyor.',
          metric: '${smallTotal.round()} ₺',
          tone: InsightTone.neutral,
        ),
      );
    }

    insights.add(
      Insight(
        title: savingsRate >= 20 ? 'Tasarruf payın güçlü.' : 'Tasarruf payın için alan var.',
        body: savingsRate >= 20
            ? 'Gelirinin yaklaşık beşte birinden fazlası sende kalıyor.'
            : 'Gelir-gider farkını biraz genişletmek aylık esnekliğini artırabilir.',
        metric: '%${savingsRate.clamp(-99, 99).toStringAsFixed(0)}',
        tone: savingsRate >= 20 ? InsightTone.positive : InsightTone.neutral,
      ),
    );

    return insights.take(4).toList(growable: false);
  }
}
