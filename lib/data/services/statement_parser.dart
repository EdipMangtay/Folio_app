import 'dart:isolate';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/transaction_record.dart';
import 'merchant_normalizer.dart';
import 'pdf_statement_reader.dart';
import 'text_decoder.dart';

enum StatementParseStatus {
  parsed,
  unsupportedFormat,
  unreadableFile,
  columnsNotRecognised,
  noTransactions,
}

class StatementParseResult {
  const StatementParseResult({
    required this.transactions,
    required this.status,
    required this.message,
    this.warnings = const <String>[],
  });

  const StatementParseResult.failure(this.status, this.message)
      : transactions = const <TransactionRecord>[],
        warnings = const <String>[];

  final List<TransactionRecord> transactions;
  final StatementParseStatus status;
  final String message;
  final List<String> warnings;

  bool get isSuccess => status == StatementParseStatus.parsed;
}

/// Parses bank and card statement exports locally on the device.
///
/// The parser never invents rows. When a file cannot be mapped with confidence
/// it returns a failure so the user is told what went wrong instead of being
/// shown plausible-looking numbers that are not theirs.
class StatementParser {
  const StatementParser();

  static const List<String> _incomeHints = <String>[
    'MAAS',
    'IADE',
    'FAIZ',
    'TEMETTU',
    'GELEN HAVALE',
    'GELEN EFT',
    'GELEN TRANSFER',
    'PARA GIRISI',
    'EMEKLI',
    'KIRA GELIRI',
  ];

  /// Statement footer/summary lines that must not become transactions.
  static const List<String> _summaryRows = <String>[
    'TOPLAM',
    'ARA TOPLAM',
    'GENEL TOPLAM',
    'BAKIYE',
    'DEVREDEN BAKIYE',
    'ONCEKI BAKIYE',
    'SON BAKIYE',
    'ACILIS BAKIYESI',
    'KAPANIS BAKIYESI',
    'DONEM SONU BAKIYE',
    'TOPLAM BORC',
    'TOPLAM ALACAK',
    'ASGARI ODEME TUTARI',
    'SON ODEME TARIHI',
    'HESAP OZETI',
    'DONEM ICI ISLEMLER',
    'KULLANILABILIR LIMIT',
  ];

  Future<StatementParseResult> parse(PlatformFile file) async {
    return parseNamedBytes(name: file.name, bytes: await file.readAsBytes());
  }

  Future<StatementParseResult> parseNamedBytes({
    required String name,
    required List<int> bytes,
  }) async {
    final String extension = _extensionOf(name);

    if (bytes.isEmpty) {
      return const StatementParseResult.failure(
        StatementParseStatus.unreadableFile,
        'Dosya boş görünüyor. Bankandan yeniden indirip tekrar dene.',
      );
    }

    // The file picker deliberately lets any file through, so the real format is
    // decided by content first and the file name second. Downloads folders are
    // full of files with a missing or wrong extension.
    final _FileKind kind = _detectKind(extension, bytes);

    if (kind == _FileKind.binary) {
      return const StatementParseResult.failure(
        StatementParseStatus.unsupportedFormat,
        'Bu dosya bir tablo ya da metin dosyası değil. Bankandan indirdiğin '
        'CSV veya Excel (XLSX) ekstreyi seç.',
      );
    }

    final List<List<String>> rows;
    try {
      rows = switch (kind) {
        _FileKind.pdf => await _readPdf(bytes),
        _FileKind.spreadsheet => _readXlsx(bytes),
        _ => _readCsv(bytes),
      };
    } on Object {
      return StatementParseResult.failure(
        StatementParseStatus.unreadableFile,
        kind == _FileKind.pdf
            ? 'PDF açıldı ama içinde okunabilir bir işlem tablosu bulunamadı. '
                'Taranmış (fotoğraf) bir ekstre ya da parola korumalı olabilir. '
                'Bankandan aynı dönemi CSV veya Excel olarak indirmeyi dene.'
            : 'Dosya açılamadı. Bozulmuş ya da parola korumalı olabilir.',
      );
    }

    return _parseRows(
      rows,
      sourceLabel: switch (kind) {
        _FileKind.pdf => 'PDF',
        _FileKind.spreadsheet => 'XLSX',
        _ => 'CSV',
      },
    );
  }

  /// PDF text extraction is pure Dart and can take a second or two on a long
  /// statement, so it runs off the UI isolate.
  Future<List<List<String>>> _readPdf(List<int> bytes) {
    return Isolate.run(() => PdfStatementReader.readRows(bytes));
  }

  List<List<String>> _readCsv(List<int> bytes) {
    final String content = TextDecoder.decode(bytes);
    final List<List<dynamic>> decoded = Csv().decode(content);
    return decoded
        .map(
          (List<dynamic> row) =>
              row.map((dynamic value) => value.toString().trim()).toList(growable: false),
        )
        .toList(growable: false);
  }

  List<List<String>> _readXlsx(List<int> bytes) {
    final Excel workbook = Excel.decodeBytes(bytes);
    Sheet? selected;
    for (final String name in workbook.tables.keys) {
      final Sheet? sheet = workbook.tables[name];
      if (sheet != null && sheet.rows.length > 1) {
        selected = sheet;
        break;
      }
    }
    if (selected == null) throw const FormatException('Workbook empty');
    return selected.rows
        .map((List<Data?> row) => row.map(_cellText).toList(growable: false))
        .toList(growable: false);
  }

  StatementParseResult _parseRows(
    List<List<String>> rows, {
    required String sourceLabel,
  }) {
    if (rows.length < 2) {
      return const StatementParseResult.failure(
        StatementParseStatus.noTransactions,
        'Dosyada işlem satırı bulunamadı.',
      );
    }

    final int headerRow = _findHeaderRow(rows);
    if (headerRow < 0) {
      return const StatementParseResult.failure(
        StatementParseStatus.columnsNotRecognised,
        'Ekstrenin sütun başlıkları tanınamadı. Dosyada en az bir açıklama '
        '(Açıklama / İşyeri) ve bir tutar (Tutar / Borç / Alacak) sütunu olmalı.',
      );
    }

    final List<String> headers = rows[headerRow].map(_canonical).toList(growable: false);
    final _ColumnMap columns = _resolveColumns(headers);

    if (columns.merchant < 0 || !columns.hasAmountSource) {
      return const StatementParseResult.failure(
        StatementParseStatus.columnsNotRecognised,
        'Açıklama ve tutar sütunları eşleştirilemedi. Ekstreyi bankandan '
        'standart CSV olarak indirmeyi dene.',
      );
    }

    final List<List<String>> dataRows = rows.skip(headerRow + 1).toList(growable: false);

    // A single signed amount column only tells expense from income when the
    // statement actually uses both signs. Card statements list every purchase
    // as a positive number, so the sign is only trusted when both appear.
    bool sawNegative = false;
    bool sawPositive = false;
    if (columns.usesGenericAmount) {
      for (final List<String> row in dataRows) {
        final double? value = _cell(row, columns.amount);
        if (value == null || value == 0) continue;
        if (value < 0) {
          sawNegative = true;
        } else {
          sawPositive = true;
        }
      }
    }
    final bool signIsDirectional = sawNegative && sawPositive;

    const Uuid uuid = Uuid();
    final List<TransactionRecord> items = <TransactionRecord>[];
    int skippedSummaryRows = 0;
    int rowsWithoutDate = 0;

    for (final List<String> row in dataRows) {
      if (columns.merchant >= row.length) continue;
      final String rawMerchant = row[columns.merchant].trim();
      if (rawMerchant.isEmpty) continue;

      if (_isSummaryRow(rawMerchant)) {
        skippedSummaryRows++;
        continue;
      }

      final double? debit = _cell(row, columns.debit);
      final double? credit = _cell(row, columns.credit);
      final double? generic = _cell(row, columns.amount);

      final TransactionType type;
      final double amount;
      if (debit != null && debit != 0) {
        type = TransactionType.expense;
        amount = debit.abs();
      } else if (credit != null && credit != 0) {
        type = TransactionType.income;
        amount = credit.abs();
      } else if (generic != null && generic != 0) {
        amount = generic.abs();
        if (signIsDirectional) {
          type = generic < 0 ? TransactionType.expense : TransactionType.income;
        } else {
          type = _looksLikeIncome(rawMerchant) ? TransactionType.income : TransactionType.expense;
        }
      } else {
        continue;
      }

      final String merchant = MerchantNormalizer.normalize(rawMerchant);
      final DateTime? parsedDate =
          columns.date >= 0 && columns.date < row.length ? _parseDate(row[columns.date]) : null;
      if (parsedDate == null) rowsWithoutDate++;

      items.add(
        TransactionRecord(
          id: uuid.v4(),
          title: merchant,
          merchant: merchant,
          category: type == TransactionType.income
              ? _incomeCategoryFor(rawMerchant)
              : MerchantNormalizer.categoryFor(merchant),
          amount: amount,
          date: parsedDate ?? DateTime.now(),
          type: type,
          source: TransactionSource.statement,
          paymentLabel: '$sourceLabel ekstre içe aktarımı',
        ),
      );
    }

    if (items.isEmpty) {
      return const StatementParseResult.failure(
        StatementParseStatus.noTransactions,
        'Sütunlar eşleşti ama okunabilir bir işlem satırı bulunamadı.',
      );
    }

    final int incomeCount = items.where((TransactionRecord item) => item.isIncome).length;
    final int expenseCount = items.length - incomeCount;

    final List<String> warnings = <String>[];
    // Only an all-positive amount column is ambiguous. An all-negative one is
    // simply a statement without income in this period.
    if (columns.usesGenericAmount && sawPositive && !sawNegative) {
      warnings.add(
        'Tutar sütununda eksi/artı ayrımı yok; tüm satırlar gider kabul edildi. '
        'Gelir olanları listeden düzeltebilirsin.',
      );
    }
    if (columns.date < 0) {
      warnings.add('Tarih sütunu bulunamadı, işlemlere bugünün tarihi verildi.');
    } else if (rowsWithoutDate > 0) {
      warnings.add('$rowsWithoutDate satırın tarihi okunamadı, bugünün tarihi kullanıldı.');
    }
    if (skippedSummaryRows > 0) {
      warnings.add('$skippedSummaryRows toplam/bakiye satırı atlandı.');
    }

    return StatementParseResult(
      transactions: items,
      status: StatementParseStatus.parsed,
      message: '${items.length} işlem okundu · $expenseCount gider, $incomeCount gelir.',
      warnings: warnings,
    );
  }

  int _findHeaderRow(List<List<String>> rows) {
    final int limit = rows.length < 25 ? rows.length : 25;
    for (int i = 0; i < limit; i++) {
      final List<String> candidate = rows[i].map(_canonical).toList(growable: false);
      final bool hasMerchant = candidate.any(
        (String header) => _containsAny(header, const <String>[
          'ACIKLAMA',
          'ISYERI',
          'MERCHANT',
          'DESCRIPTION',
          'DETAY',
          'ISLEM',
        ]),
      );
      final bool hasMoney = candidate.any(
        (String header) => _containsAny(header, const <String>[
          'TUTAR',
          'AMOUNT',
          'MIKTAR',
          'BORC',
          'DEBIT',
          'ALACAK',
          'CREDIT',
        ]),
      );
      if (hasMerchant && hasMoney) return i;
    }
    return -1;
  }

  /// Maps header names to column indexes.
  ///
  /// Each column claims its index so a header can only be used once. This is
  /// what keeps `İşlem Tarihi` from being picked as the description column
  /// merely because it contains the word `İşlem`.
  _ColumnMap _resolveColumns(List<String> headers) {
    final Set<int> claimed = <int>{};

    int pick(List<List<String>> tiers, {List<String> forbidden = const <String>[]}) {
      for (final List<String> tier in tiers) {
        for (int i = 0; i < headers.length; i++) {
          if (claimed.contains(i)) continue;
          final String header = headers[i];
          if (header.isEmpty) continue;
          if (_containsAny(header, forbidden)) continue;
          if (_containsAny(header, tier)) {
            claimed.add(i);
            return i;
          }
        }
      }
      return -1;
    }

    const List<String> balanceLike = <String>['BAKIYE', 'BALANCE', 'LIMIT', 'KUR', 'ORAN'];

    final int date = pick(
      const <List<String>>[
        <String>['ISLEM TARIHI', 'TRANSACTION DATE'],
        <String>['TARIH', 'DATE'],
      ],
    );
    final int debit = pick(
      const <List<String>>[
        <String>['BORC', 'DEBIT', 'CIKIS', 'CIKAN', 'HARCAMA'],
      ],
      forbidden: balanceLike,
    );
    final int credit = pick(
      const <List<String>>[
        <String>['ALACAK', 'CREDIT', 'GIRIS', 'GIREN'],
      ],
      forbidden: balanceLike,
    );
    final int amount = pick(
      const <List<String>>[
        <String>['ISLEM TUTARI', 'TRANSACTION AMOUNT'],
        <String>['TUTAR', 'AMOUNT', 'MIKTAR'],
      ],
      forbidden: balanceLike,
    );
    final int merchant = pick(
      const <List<String>>[
        <String>['ACIKLAMA', 'ISYERI', 'MERCHANT', 'DESCRIPTION', 'DETAY', 'ETIKET'],
        <String>['ISLEM'],
      ],
      forbidden: const <String>['TARIH', 'TUTAR', 'BAKIYE', 'DATE'],
    );

    return _ColumnMap(date: date, merchant: merchant, amount: amount, debit: debit, credit: credit);
  }

  double? _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) return null;
    return _parseAmount(row[index]);
  }

  bool _isSummaryRow(String rawMerchant) {
    final String canonical = _canonical(rawMerchant).replaceAll(RegExp(r'[^A-Z ]'), '').trim();
    if (canonical.isEmpty) return false;
    return _summaryRows.contains(canonical);
  }

  bool _looksLikeIncome(String rawMerchant) {
    final String canonical = _canonical(rawMerchant);
    return _incomeHints.any(canonical.contains);
  }

  String _incomeCategoryFor(String rawMerchant) {
    final String canonical = _canonical(rawMerchant);
    if (canonical.contains('MAAS') || canonical.contains('EMEKLI')) return 'Maaş';
    if (canonical.contains('IADE')) return 'İade';
    if (canonical.contains('FAIZ') || canonical.contains('TEMETTU')) return 'Yatırım Getirisi';
    if (canonical.contains('FREELANCE')) return 'Freelance';
    return 'Diğer Gelir';
  }

  /// Works out what a file really is.
  ///
  /// Magic bytes win over the file name: a statement saved as `ekstre` with no
  /// extension, or an XLSX that arrived named `.xls`, should still open.
  _FileKind _detectKind(String extension, List<int> bytes) {
    if (_startsWith(bytes, const <int>[0x25, 0x50, 0x44, 0x46])) return _FileKind.pdf; // %PDF
    // XLSX is a zip container. Old binary .xls files start with a different
    // signature and the excel package cannot read them.
    if (_startsWith(bytes, const <int>[0x50, 0x4B, 0x03, 0x04])) return _FileKind.spreadsheet;
    if (extension == 'pdf') return _FileKind.pdf;
    if (extension == 'xlsx' || extension == 'xls') return _FileKind.spreadsheet;

    // Text formats never contain NUL bytes; images and archives do.
    final int scanLength = bytes.length < 1024 ? bytes.length : 1024;
    for (int i = 0; i < scanLength; i++) {
      if (bytes[i] == 0) return _FileKind.binary;
    }
    return _FileKind.delimitedText;
  }

  bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  String _cellText(Data? cell) => cell?.value?.toString().trim() ?? '';

  String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Parses a money cell, preserving the sign.
  ///
  /// Handles `1.284,40`, `1,284.40`, trailing minus (`230,00-`) and accounting
  /// parentheses (`(230,00)`), all of which appear in Turkish bank exports.
  double? _parseAmount(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final bool parenthesised = trimmed.startsWith('(') && trimmed.endsWith(')');
    String value = trimmed.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (value.isEmpty || value == '-') return null;

    final bool negative = parenthesised || value.startsWith('-') || value.endsWith('-');
    value = value.replaceAll('-', '');
    if (value.isEmpty) return null;

    if (value.contains(',') && value.contains('.')) {
      if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (value.contains(',')) {
      value = value.replaceAll(',', '.');
    } else if (value.contains('.')) {
      // `1.284` with no decimal part is a thousands separator, not a decimal.
      final int dot = value.lastIndexOf('.');
      final bool looksLikeThousands = value.length - dot - 1 == 3 && value.indexOf('.') == dot;
      if (looksLikeThousands) value = value.replaceAll('.', '');
    }

    final double? parsed = double.tryParse(value);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  DateTime? _parseDate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return null;

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
        .replaceAll('Ü', 'U')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}

enum _FileKind { pdf, spreadsheet, delimitedText, binary }

class _ColumnMap {
  const _ColumnMap({
    required this.date,
    required this.merchant,
    required this.amount,
    required this.debit,
    required this.credit,
  });

  final int date;
  final int merchant;
  final int amount;
  final int debit;
  final int credit;

  bool get hasAmountSource => amount >= 0 || debit >= 0 || credit >= 0;

  /// True when the type has to be inferred from a single amount column.
  bool get usesGenericAmount => amount >= 0 && debit < 0 && credit < 0;
}
