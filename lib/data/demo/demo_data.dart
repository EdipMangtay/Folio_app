import '../../domain/models/budget_record.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/transaction_record.dart';

abstract final class DemoData {
  static List<TransactionRecord> transactions() {
    final DateTime now = DateTime.now();
    const List<(String, String, double)> merchants = <(String, String, double)>[
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
      ('Netflix', 'Abonelik', 229),
      ('Spotify', 'Abonelik', 99),
    ];

    final List<TransactionRecord> items = <TransactionRecord>[];
    for (int i = 0; i < 108; i++) {
      final (String merchant, String category, double base) = merchants[i % merchants.length];
      final int dayOffset = (i * 3 + (i % 5)) % 116;
      final double variation = 0.72 + ((i * 17) % 57) / 100;
      final double amount = (base * variation + (i % 4) * 18).roundToDouble();
      final DateTime date = DateTime(
        now.year,
        now.month,
        now.day,
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

    for (int monthOffset = 0; monthOffset < 4; monthOffset++) {
      final DateTime incomeDate = DateTime(now.year, now.month - monthOffset, 1, 9);
      items.add(
        TransactionRecord(
          id: 'demo_income_$monthOffset',
          title: 'Aylık gelir',
          category: 'Finans',
          amount: 52000 + monthOffset * 900,
          date: incomeDate,
          type: TransactionType.income,
          source: TransactionSource.demo,
          paymentLabel: 'Ana hesap',
        ),
      );
    }

    items.sort((TransactionRecord a, TransactionRecord b) => b.date.compareTo(a.date));
    return items;
  }

  static List<BudgetRecord> budgets() => const <BudgetRecord>[
        BudgetRecord(id: 'budget_food', category: 'Yeme & İçme', limitAmount: 8000),
        BudgetRecord(id: 'budget_market', category: 'Market', limitAmount: 7500),
        BudgetRecord(id: 'budget_transport', category: 'Ulaşım', limitAmount: 6500),
        BudgetRecord(id: 'budget_shopping', category: 'Alışveriş', limitAmount: 5500),
      ];

  static List<SubscriptionRecord> subscriptions() {
    final DateTime now = DateTime.now();
    return <SubscriptionRecord>[
      SubscriptionRecord(
        id: 'sub_netflix',
        merchant: 'Netflix',
        category: 'Video',
        monthlyAmount: 229,
        nextBillingDate: DateTime(now.year, now.month + 1, 5),
      ),
      SubscriptionRecord(
        id: 'sub_spotify',
        merchant: 'Spotify',
        category: 'Müzik',
        monthlyAmount: 99,
        nextBillingDate: DateTime(now.year, now.month + 1, 8),
      ),
      SubscriptionRecord(
        id: 'sub_icloud',
        merchant: 'iCloud+',
        category: 'Depolama',
        monthlyAmount: 79,
        nextBillingDate: DateTime(now.year, now.month + 1, 11),
      ),
      SubscriptionRecord(
        id: 'sub_adobe',
        merchant: 'Adobe',
        category: 'Üretkenlik',
        monthlyAmount: 478,
        nextBillingDate: DateTime(now.year, now.month + 1, 16),
      ),
    ];
  }
}
