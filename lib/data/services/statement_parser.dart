import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/transaction_record.dart';
import 'merchant_normalizer.dart';

class StatementParseResult {
  const StatementParseResult({
    required this.transactions,
    required this.isDemoFallback,
    required this.message,
  });

  final List<TransactionRecord> transactions;
  final bool isDemoFallback;
  final String message;
}

/// Parses common statement exports locally on the device.
///
/// CSV and XLSX are parsed directly. PDF is intentionally routed to a review
/// adapter because bank PDF layouts differ widely and silent financial parsing
/// mistakes are worse than asking the user to confirm imported rows.
class StatementParser {
  const StatementParser();

  Future<StatementParseResult> parse(PlatformFile file) async {
    return parseNamedBytes(
      name: file.name,
      bytes: await file.readAsBytes(),
    );
  }

  Future<StatementParseResult> parseNamedBytes({
    required String name,
    required List<int> bytes,
  }) async {
    final String extension = _extensionOf(name);

    try {
      if (extension == 'csv' && bytes.isNotEmpty) {
        return _parseCsv(bytes);
      }
      if (extension == 'xlsx' && bytes.isNotEmpty) {
        return _parseXlsx(bytes);
      }
    } on Object {
      return _fallback(
        'Dosyadaki sütunları güvenle eşleştiremedik. Kaydetmeden önce örnek önizlemeyi kontrol et.',
      );
    }

    if (extension == 'pdf') {
      return _fallback(
        'PDF ekstre düzenleri bankaya göre değiştiği için bu sürüm doğrulamalı önizleme kullanıyor. CSV veya XLSX doğrudan ayrıştırılır.',
      );
    }

    return _fallback('Bu dosya biçimi için doğrulamalı örnek önizleme kullanılıyor.');
  }

  StatementParseResult _parseCsv(List<int> bytes) {
    final String content = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
    final List<List<dynamic>> decoded = Csv().decode(content);
    final List<List<String>> rows = decoded
        .map((List<dynamic> row) => row.map((dynamic value) => value.toString().trim()).toList(growable: false))
        .toList(growable: false);
    return _parseRows(rows, sourceLabel: 'CSV');
  }

  StatementParseResult _parseXlsx(List<int> bytes) {
    final Excel workbook = Excel.decodeBytes(bytes);
    Sheet? selected;
    for (final String name in workbook.tables.keys) {
      final Sheet? sheet = workbook.tables[name];
      if (sheet != null && sheet.rows.isNotEmpty) {
        selected = sheet;
        break;
      }
    }
    if (selected == null) throw const FormatException('Workbook empty');

    final List<List<String>> rows = selected.rows
        .map(
          (List<Data?> row) => row.map(_cellText).toList(growable: false),
        )
        .toList(growable: false);
    return _parseRows(rows, sourceLabel: 'XLSX');
  }

  StatementParseResult _parseRows(
    List<List<String>> rows, {
    required String sourceLabel,
  }) {
    if (rows.length < 2) throw const FormatException('No data');

    // Some banks place a title/metadata block above the real header. Search the
    // first 15 rows for a row that looks like a statement header.
    int headerRow = -1;
    for (int i = 0; i < rows.length && i < 15; i++) {
      final List<String> candidate = rows[i].map(_canonical).toList(growable: false);
      final bool hasMerchant = candidate.any(
        (String h) => _containsAny(h, const <String>['ACIKLAMA', 'ISLEM', 'MERCHANT', 'DESCRIPTION', 'ISYERI']),
      );
      final bool hasMoney = candidate.any(
        (String h) => _containsAny(h, const <String>['TUTAR', 'AMOUNT', 'BORC', 'DEBIT', 'ALACAK', 'CREDIT']),
      );
      if (hasMerchant && hasMoney) {
        headerRow = i;
        break;
      }
    }
    if (headerRow < 0) throw const FormatException('Header not found');

    final List<String> headers = rows[headerRow].map(_canonical).toList(growable: false);
    int find(List<String> names) => headers.indexWhere(
          (String header) => names.any(header.contains),
        );

    final int merchantIndex = find(const <String>['MERCHANT', 'ACIKLAMA', 'ISLEM', 'DESCRIPTION', 'ISYERI']);
    final int amountIndex = find(const <String>['TUTAR', 'AMOUNT']);
    final int debitIndex = find(const <String>['BORC', 'DEBIT']);
    final int creditIndex = find(const <String>['ALACAK', 'CREDIT']);
    final int dateIndex = find(const <String>['TARIH', 'DATE', 'ISLEM TARIHI']);

    if (merchantIndex < 0 || (amountIndex < 0 && debitIndex < 0 && creditIndex < 0)) {
      throw const FormatException('Required columns missing');
    }

    const Uuid uuid = Uuid();
    final List<TransactionRecord> items = <TransactionRecord>[];
    for (final List<String> row in rows.skip(headerRow + 1)) {
      if (merchantIndex >= row.length) continue;
      final String rawMerchant = row[merchantIndex].trim();
      if (rawMerchant.isEmpty) continue;

      final double? debit = debitIndex >= 0 && debitIndex < row.length ? _parseAmount(row[debitIndex]) : null;
      final double? credit = creditIndex >= 0 && creditIndex < row.length ? _parseAmount(row[creditIndex]) : null;
      final double? generic = amountIndex >= 0 && amountIndex < row.length ? _parseAmount(row[amountIndex]) : null;

      final TransactionType type;
      final double rawAmount;
      if (debit != null && debit != 0) {
        type = TransactionType.expense;
        rawAmount = debit.abs();
      } else if (credit != null && credit != 0) {
        type = TransactionType.income;
        rawAmount = credit.abs();
      } else if (generic != null && generic != 0) {
        // Folio is primarily optimized for card statements. A generic signed
        // amount is therefore imported as an expense and shown in review.
        type = TransactionType.expense;
        rawAmount = generic.abs();
      } else {
        continue;
      }

      final String merchant = MerchantNormalizer.normalize(rawMerchant);
      final DateTime date = dateIndex >= 0 && dateIndex < row.length
          ? _parseDate(row[dateIndex]) ?? DateTime.now()
          : DateTime.now();

      items.add(
        TransactionRecord(
          id: uuid.v4(),
          title: merchant,
          merchant: merchant,
          category: type == TransactionType.income ? 'Finans' : MerchantNormalizer.categoryFor(merchant),
          amount: rawAmount,
          date: date,
          type: type,
          source: TransactionSource.statement,
          paymentLabel: '$sourceLabel ekstre içe aktarımı',
        ),
      );
    }

    if (items.isEmpty) throw const FormatException('No rows');
    return StatementParseResult(
      transactions: items,
      isDemoFallback: false,
      message: '${items.length} işlem bulundu. Kaydetmeden önce kategorileri kontrol et.',
    );
  }

  StatementParseResult _fallback(String message) {
    const Uuid uuid = Uuid();
    final DateTime now = DateTime.now();
    final List<(String, double)> demo = <(String, double)>[
      ('Starbucks', 230),
      ('Getir', 720),
      ('Netflix', 229),
      ('Shell', 1850),
      ('Trendyol', 1160),
    ];
    return StatementParseResult(
      transactions: demo.indexed.map((pair) {
        final int index = pair.$1;
        final (String merchant, double amount) = pair.$2;
        return TransactionRecord(
          id: uuid.v4(),
          title: merchant,
          merchant: merchant,
          category: MerchantNormalizer.categoryFor(merchant),
          amount: amount,
          date: now.subtract(Duration(days: index * 2 + 1)),
          type: TransactionType.expense,
          source: TransactionSource.statement,
          paymentLabel: 'Ekstre önizlemesi',
        );
      }).toList(growable: false),
      isDemoFallback: true,
      message: message,
    );
  }

  String _cellText(Data? cell) {
    return cell?.value?.toString() ?? '';
  }

  String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  double? _parseAmount(String raw) {
    String value = raw.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (value.isEmpty || value == '-') return null;
    if (value.contains(',') && value.contains('.')) {
      if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (value.contains(',')) {
      value = value.replaceAll(',', '.');
    }
    return double.tryParse(value);
  }

  DateTime? _parseDate(String raw) {
    final String value = raw.trim();
    final DateTime? iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final RegExpMatch? match = RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})').firstMatch(value);
    if (match == null) return null;
    final int day = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    int year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final DateTime result = DateTime(year, month, day);
    if (result.day != day || result.month != month || result.year != year) return null;
    return result;
  }

  bool _containsAny(String value, List<String> needles) => needles.any(value.contains);

  String _canonical(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ğ', 'G')
        .replaceAll('İ', 'I')
        .replaceAll('Ö', 'O')
        .replaceAll('Ş', 'S')
        .replaceAll('Ü', 'U');
  }
}
