abstract final class AppConstants {
  static const String appName = 'Folio';
  static const String currencyCode = 'TRY';
  static const String currencySymbol = '₺';

  static const List<String> expenseCategories = <String>[
    'Yeme & İçme',
    'Market',
    'Ulaşım',
    'Alışveriş',
    'Ev',
    'Faturalar',
    'Sağlık',
    'Eğitim',
    'Eğlence',
    'Seyahat',
    'Kahve',
    'Abonelik',
    'Teknoloji',
    'Kişisel Bakım',
    'Spor',
    'Diğer',
  ];

  static const List<String> incomeCategories = <String>[
    'Maaş',
    'Freelance',
    'Nakit Girişi',
    'Yatırım Getirisi',
    'Satış',
    'İade',
    'Hediye',
    'Diğer Gelir',
  ];

  static const List<String> categories = <String>[
    ...expenseCategories,
    ...incomeCategories,
    'Finans',
  ];

  static const String defaultPaymentLabel = 'Mastercard •••• 4832';
  static const String defaultIncomeLabel = 'Banka hesabı';
}
