import '../../domain/models/budget_record.dart';
import '../../domain/models/goal_record.dart';
import '../../domain/models/transaction_record.dart';

abstract final class DemoData {
  /// Merchants used for one-off spending. Recurring services are generated
  /// separately below so they form a clean monthly rhythm.
  static const List<(String, String, double)> _merchants = <(String, String, double)>[
    ('Starbucks', 'Kahve', 185),
    ('Migros', 'Market', 780),
    ('Getir', 'Market', 540),
    ('Yemeksepeti', 'Yeme & İçme', 620),
    ('Trendyol', 'Alışveriş', 940),
    ('Shell', 'Ulaşım', 1450),
    ('Uber', 'Ulaşım', 310),
    ('CarrefourSA', 'Market', 710),
    ('Amazon', 'Alışveriş', 860),
    ('Apple', 'Teknoloji', 249),
    ('Turkcell', 'Faturalar', 485),
  ];

  /// Services billed on the same day every month, so the subscription
  /// detector has something real to find.
  static const List<(String, String, double, int)> _recurring = <(String, String, double, int)>[
    ('Netflix', 'Abonelik', 229, 5),
    ('Spotify', 'Abonelik', 99, 8),
    ('iCloud+', 'Abonelik', 79, 11),
    ('Adobe', 'Teknoloji', 478, 16),
  ];

  static List<TransactionRecord> transactions({DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    final List<TransactionRecord> items = <TransactionRecord>[];

    for (int i = 0; i < 96; i++) {
      final (String merchant, String category, double base) = _merchants[i % _merchants.length];
      final int dayOffset = (i * 3 + (i % 5)) % 116;
      final double variation = 0.72 + ((i * 17) % 57) / 100;
      final double amount = (base * variation + (i % 4) * 18).roundToDouble();
      final DateTime date = DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
        10 + (i % 11),
        (i * 7) % 60,
      ).subtract(Duration(days: dayOffset));
      items.add(
        TransactionRecord(
          id: 'demo_expense_$i',
          title: merchant,
          merchant: merchant,
          category: category,
          amount: amount,
          date: date,
          type: TransactionType.expense,
          source: TransactionSource.demo,
          paymentLabel: i % 3 == 0 ? 'Visa •••• 2048' : 'Mastercard •••• 4832',
        ),
      );
    }

    for (final (String merchant, String category, double amount, int billingDay) in _recurring) {
      for (int monthOffset = 0; monthOffset < 5; monthOffset++) {
        final DateTime date = DateTime(anchor.year, anchor.month - monthOffset, billingDay, 9);
        if (date.isAfter(anchor)) continue;
        items.add(
          TransactionRecord(
            id: 'demo_sub_${merchant.toLowerCase()}_$monthOffset',
            title: merchant,
            merchant: merchant,
            category: category,
            amount: amount,
            date: date,
            type: TransactionType.expense,
            source: TransactionSource.demo,
            paymentLabel: 'Visa •••• 2048',
          ),
        );
      }
    }

    for (int monthOffset = 0; monthOffset < 4; monthOffset++) {
      items.add(
        TransactionRecord(
          id: 'demo_income_$monthOffset',
          title: 'Aylık gelir',
          category: 'Maaş',
          amount: 52000 + monthOffset * 900,
          date: DateTime(anchor.year, anchor.month - monthOffset, 1, 9),
          type: TransactionType.income,
          source: TransactionSource.demo,
          paymentLabel: 'Ana hesap',
        ),
      );
    }

    items.sort((TransactionRecord a, TransactionRecord b) => b.date.compareTo(a.date));
    return items;
  }

  /// Default category limits. These are settings rather than fabricated
  /// history, so they are seeded for every wallet — demo or not.
  static List<BudgetRecord> budgets() => const <BudgetRecord>[
        BudgetRecord(id: 'budget_food', category: 'Yeme & İçme', limitAmount: 8000),
        BudgetRecord(id: 'budget_market', category: 'Market', limitAmount: 7500),
        BudgetRecord(id: 'budget_transport', category: 'Ulaşım', limitAmount: 6500),
        BudgetRecord(id: 'budget_shopping', category: 'Alışveriş', limitAmount: 5500),
      ];

  /// Default savings goals.
  static List<GoalRecord> goals() {
    final DateTime now = DateTime.now();
    return <GoalRecord>[
      GoalRecord(
        id: 'goal_emergency',
        title: 'Acil Durum Fonu',
        targetAmount: 50000,
        savedAmount: 32500,
        category: 'Tasarruf',
        targetDate: DateTime(now.year, now.month + 4, 1),
        note: '6 aylık temel gider güvencesi',
      ),
      GoalRecord(
        id: 'goal_vacation',
        title: 'Yaz Tatili',
        targetAmount: 35000,
        savedAmount: 22000,
        category: 'Seyahat',
        targetDate: DateTime(now.year, now.month + 6, 15),
        note: 'Ege rotası tatil birikimi',
      ),
      GoalRecord(
        id: 'goal_tech',
        title: 'Yeni Ekipman',
        targetAmount: 42000,
        savedAmount: 18000,
        category: 'Teknoloji',
        targetDate: DateTime(now.year, now.month + 8, 1),
        note: 'Geliştirme ve çalışma istasyonu',
      ),
    ];
  }
}
