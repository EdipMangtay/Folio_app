import '../constants/app_constants.dart';

abstract final class Formatters {
  static const List<String> _months = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const List<String> _weekdays = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static String money(double value, {bool decimals = false}) {
    final double absValue = value.abs();
    final String fixed = absValue.toStringAsFixed(decimals ? 2 : 0);
    final List<String> parts = fixed.split('.');
    final String whole = parts.first;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      final int remaining = whole.length - i;
      buffer.write(whole[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    final String fraction = decimals ? ',${parts.last}' : '';
    return '${value < 0 ? '-' : ''}${buffer.toString()}$fraction ${AppConstants.currencySymbol}';
  }


  /// Parses user-entered money in both Turkish and international keyboard formats.
  /// Examples: 1.284,40 -> 1284.40, 1284,40 -> 1284.40, 1284.40 -> 1284.40.
  static double? parseMoneyInput(String raw) {
    String value = raw
        .trim()
        .replaceAll('−', '-')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (value.isEmpty || value == '-') return null;

    final int lastComma = value.lastIndexOf(',');
    final int lastDot = value.lastIndexOf('.');
    String? decimalSeparator;

    if (lastComma >= 0 && lastDot >= 0) {
      final int lastSeparator = lastComma > lastDot ? lastComma : lastDot;
      final int trailing = value.length - lastSeparator - 1;
      if (trailing == 1 || trailing == 2) {
        decimalSeparator = value[lastSeparator];
      }
    } else if (lastComma >= 0) {
      final int trailing = value.length - lastComma - 1;
      if (trailing == 1 || trailing == 2) decimalSeparator = ',';
    } else if (lastDot >= 0) {
      final int trailing = value.length - lastDot - 1;
      if (trailing == 1 || trailing == 2) decimalSeparator = '.';
    }

    if (decimalSeparator != null) {
      final int decimalIndex = value.lastIndexOf(decimalSeparator);
      final String whole = value
          .substring(0, decimalIndex)
          .replaceAll(',', '')
          .replaceAll('.', '');
      final String fraction = value.substring(decimalIndex + 1);
      value = '$whole.$fraction';
    } else {
      value = value.replaceAll(',', '').replaceAll('.', '');
    }
    return double.tryParse(value);
  }

  static String signedMoney(double value) {
    final String prefix = value > 0 ? '+' : value < 0 ? '−' : '';
    return '$prefix${money(value.abs())}';
  }

  static String monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';
  static String month(DateTime date) => _months[date.month - 1];
  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  static String shortDate(DateTime date) => '${date.day} ${_months[date.month - 1].substring(0, 3)}';

  static String fullDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

  static String relativeDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(date.year, date.month, date.day);
    final int days = today.difference(target).inDays;
    if (days == 0) return 'Bugün';
    if (days == 1) return 'Dün';
    if (days > 1 && days < 7) return '$days gün önce';
    return shortDate(date);
  }

  static String percent(double value, {int digits = 1}) {
    final String prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(digits).replaceAll('.', ',')}%';
  }
}
