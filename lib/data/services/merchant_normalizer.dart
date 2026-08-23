abstract final class MerchantNormalizer {
  static const Map<String, String> _aliases = <String, String>{
    'STARBUCKS': 'Starbucks',
    'MIGROS': 'Migros',
    'MIGROS TICARET': 'Migros',
    'GETIR': 'Getir',
    'YEMEKSEPETI': 'Yemeksepeti',
    'TRENDYOL': 'Trendyol',
    'AMAZON': 'Amazon',
    'NETFLIX': 'Netflix',
    'SPOTIFY': 'Spotify',
    'APPLE.COM/BILL': 'Apple',
    'APPLE': 'Apple',
    'SHELL': 'Shell',
    'UBER': 'Uber',
    'TURKCELL': 'Turkcell',
    'TURK TELEKOM': 'Türk Telekom',
    'CARREFOUR': 'CarrefourSA',
  };

  static String normalize(String raw) {
    final String cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String upper = cleaned.toUpperCase();
    for (final MapEntry<String, String> entry in _aliases.entries) {
      if (upper.contains(entry.key)) return entry.value;
    }
    if (cleaned.isEmpty) return 'İşlem';
    return cleaned
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .map((String part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String categoryFor(String merchant) {
    final String upper = merchant.toUpperCase();
    if (upper.contains('STARBUCKS') || upper.contains('KAHVE')) return 'Kahve';
    if (upper.contains('MIGROS') || upper.contains('CARREFOUR') || upper.contains('GETIR')) {
      return 'Market';
    }
    if (upper.contains('YEMEK') || upper.contains('RESTAURANT') || upper.contains('CAFE')) {
      return 'Yeme & İçme';
    }
    if (upper.contains('NETFLIX') || upper.contains('SPOTIFY') || upper.contains('ICLOUD')) {
      return 'Abonelik';
    }
    if (upper.contains('SHELL') || upper.contains('UBER') || upper.contains('TAXI')) {
      return 'Ulaşım';
    }
    if (upper.contains('TRENDYOL') || upper.contains('AMAZON')) return 'Alışveriş';
    if (upper.contains('APPLE') || upper.contains('ADOBE')) return 'Teknoloji';
    if (upper.contains('TURKCELL') || upper.contains('TELEKOM')) return 'Faturalar';
    return 'Diğer';
  }
}
