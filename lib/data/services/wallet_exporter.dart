import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../domain/models/transaction_record.dart';

/// Writes the wallet out as a CSV the user owns.
///
/// The layout is deliberately the same shape Folio can read back: semicolon
/// delimited, signed amounts and a `Tarih` / `Açıklama` / `Tutar` trio. So the
/// exported file opens in Excel and can also be re-imported.
abstract final class WalletExporter {
  static const List<String> header = <String>[
    'Tarih',
    'Açıklama',
    'Kategori',
    'Tür',
    'Tutar',
    'Ödeme',
    'Not',
  ];

  static String fileName({DateTime? now}) {
    final DateTime date = now ?? DateTime.now();
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return 'folio-${date.year}-$month-$day.csv';
  }

  static Uint8List toCsvBytes(List<TransactionRecord> transactions) {
    return Uint8List.fromList(utf8.encode(toCsv(transactions)));
  }

  static String toCsv(List<TransactionRecord> transactions) {
    final List<TransactionRecord> sorted = List<TransactionRecord>.from(transactions)
      ..sort((TransactionRecord a, TransactionRecord b) => b.date.compareTo(a.date));

    final List<List<dynamic>> rows = <List<dynamic>>[
      header,
      for (final TransactionRecord item in sorted)
        <dynamic>[
          _date(item.date),
          item.title,
          item.category,
          item.isIncome ? 'Gelir' : 'Gider',
          _amount(item),
          item.paymentLabel ?? '',
          item.note ?? '',
        ],
    ];

    // The BOM keeps Excel on Windows from mangling Turkish characters.
    return Csv(fieldDelimiter: ';', lineDelimiter: '\r\n', addBom: true).encode(rows);
  }

  static String _date(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  /// Expenses are negative and income positive, which is what makes the export
  /// unambiguous when it is read back in.
  static String _amount(TransactionRecord record) {
    final String value = record.amount.toStringAsFixed(2).replaceAll('.', ',');
    return record.isIncome ? value : '-$value';
  }
}
