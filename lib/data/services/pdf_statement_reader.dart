import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Turns a PDF statement into the same row/column grid that CSV and XLSX
/// statements produce, so all of the column mapping, sign handling and summary
/// filtering in [StatementParser] applies unchanged.
///
/// Two strategies, in order:
///   1. Find the table header and read every following line by the horizontal
///      position of its words. This reconstructs the real columns and is what
///      most bank PDFs allow.
///   2. If no header exists, fall back to reading one transaction per line and
///      *verifying* which trailing number is the amount rather than guessing.
///
/// Uses syncfusion_flutter_pdf, which is free under the Syncfusion Community
/// License for individuals and small teams.
abstract final class PdfStatementReader {
  static const List<String> _descriptionWords = <String>[
    'ACIKLAMA',
    'ISYERI',
    'MERCHANT',
    'DESCRIPTION',
    'DETAY',
    'ISLEM',
  ];

  static const List<String> _moneyWords = <String>[
    'TUTAR',
    'AMOUNT',
    'MIKTAR',
    'BORC',
    'DEBIT',
    'ALACAK',
    'CREDIT',
  ];

  static final RegExp _leadingDate = RegExp(r'^(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\s+');
  static final RegExp _money = RegExp(r'^\(?-?\d{1,3}(?:[.\s]\d{3})*(?:,\d{1,2})?-?\)?$|^\(?-?\d+(?:[.,]\d{1,2})?-?\)?$');

  /// Throws when the document holds no usable statement table.
  static List<List<String>> readRows(List<int> bytes) {
    final List<_Line> lines = _extractLines(bytes);
    if (lines.isEmpty) {
      throw const FormatException('No text layer');
    }

    final List<List<String>> columnRows = _readByColumns(lines);
    if (columnRows.length > 1) return columnRows;

    final List<List<String>> lineRows = _readByLines(lines);
    if (lineRows.length > 1) return lineRows;

    throw const FormatException('No statement table found');
  }

  static List<_Line> _extractLines(List<int> bytes) {
    final PdfDocument document = PdfDocument(inputBytes: Uint8List.fromList(bytes));
    try {
      return PdfTextExtractor(document)
          .extractTextLines()
          .map(
            (TextLine line) => _Line(
              text: line.text.trim(),
              pageIndex: line.pageIndex,
              top: line.bounds.top,
              words: line.wordCollection
                  .where((TextWord word) => word.text.trim().isNotEmpty)
                  .map((TextWord word) => _Word(word.text.trim(), word.bounds))
                  .toList(growable: false),
            ),
          )
          .where((_Line line) => line.words.isNotEmpty)
          .toList(growable: false);
    } finally {
      document.dispose();
    }
  }

  // ---------------------------------------------------------------- columns

  static List<List<String>> _readByColumns(List<_Line> lines) {
    final int headerIndex = lines.indexWhere(_looksLikeHeader);
    if (headerIndex < 0) return const <List<String>>[];

    final _Line header = lines[headerIndex];
    final List<_Column> columns = _columnsOf(header);
    if (columns.length < 2) return const <List<String>>[];

    final List<List<String>> rows = <List<String>>[
      columns.map((_Column column) => column.label).toList(growable: false),
    ];

    for (final _Line line in lines.skip(headerIndex + 1)) {
      final List<String> row = _distribute(line, columns);
      if (row.every((String cell) => cell.isEmpty)) continue;
      rows.add(row);
    }
    return rows;
  }

  static bool _looksLikeHeader(_Line line) {
    final String canonical = _canonical(line.text);
    final bool hasDescription = _descriptionWords.any(canonical.contains);
    final bool hasMoney = _moneyWords.any(canonical.contains);
    return hasDescription && hasMoney && line.words.length >= 2;
  }

  /// Groups the header's words into column labels. Words belonging to one label
  /// (`İşlem` + `Tarihi`) sit close together; a real column break leaves a gap.
  static List<_Column> _columnsOf(_Line header) {
    final List<_Word> words = List<_Word>.from(header.words)
      ..sort((_Word a, _Word b) => a.bounds.left.compareTo(b.bounds.left));

    final double gapThreshold = math.max(
      12,
      words.map((_Word word) => word.bounds.height).reduce(math.max) * 1.4,
    );

    final List<_Column> columns = <_Column>[];
    List<_Word> current = <_Word>[words.first];
    for (int i = 1; i < words.length; i++) {
      final double gap = words[i].bounds.left - current.last.bounds.right;
      if (gap > gapThreshold) {
        columns.add(_Column.fromWords(current));
        current = <_Word>[words[i]];
      } else {
        current.add(words[i]);
      }
    }
    columns.add(_Column.fromWords(current));

    // Turn label extents into edge-to-edge ranges so numbers that sit slightly
    // outside their header label still land in the right column.
    for (int i = 0; i < columns.length; i++) {
      final double start = i == 0
          ? double.negativeInfinity
          : (columns[i - 1].right + columns[i].left) / 2;
      final double end = i == columns.length - 1
          ? double.infinity
          : (columns[i].right + columns[i + 1].left) / 2;
      columns[i] = columns[i].withRange(start, end);
    }
    return columns;
  }

  static List<String> _distribute(_Line line, List<_Column> columns) {
    final List<List<String>> buckets = List<List<String>>.generate(
      columns.length,
      (_) => <String>[],
      growable: false,
    );

    for (final _Word word in line.words) {
      final double centre = (word.bounds.left + word.bounds.right) / 2;
      int index = columns.indexWhere(
        (_Column column) => centre >= column.start && centre < column.end,
      );
      if (index < 0) index = centre < columns.first.start ? 0 : columns.length - 1;
      buckets[index].add(word.text);
    }

    return buckets.map((List<String> bucket) => bucket.join(' ').trim()).toList(growable: false);
  }

  // ------------------------------------------------------------------ lines

  /// One transaction per line: a leading date, a description, then one or more
  /// numbers. When several numbers trail the description the last one is often
  /// a running balance, so that hypothesis is tested against the data instead
  /// of assumed.
  static List<List<String>> _readByLines(List<_Line> lines) {
    final List<_Candidate> candidates = <_Candidate>[];
    for (final _Line line in lines) {
      final _Candidate? candidate = _candidateOf(line.text);
      if (candidate != null) candidates.add(candidate);
    }
    if (candidates.isEmpty) return const <List<String>>[];

    final bool lastIsBalance = _lastColumnIsRunningBalance(candidates);

    final List<List<String>> rows = <List<String>>[
      <String>['Tarih', 'Açıklama', 'Tutar'],
    ];
    for (final _Candidate candidate in candidates) {
      final String amount = candidate.amountAt(lastIsBalance);
      if (amount.isEmpty) continue;
      rows.add(<String>[candidate.date, candidate.description, amount]);
    }
    return rows;
  }

  static _Candidate? _candidateOf(String text) {
    final RegExpMatch? dateMatch = _leadingDate.firstMatch(text);
    if (dateMatch == null) return null;

    final List<String> tokens = text
        .substring(dateMatch.end)
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;

    final List<String> trailingNumbers = <String>[];
    while (tokens.isNotEmpty && _money.hasMatch(tokens.last)) {
      trailingNumbers.insert(0, tokens.removeLast());
    }
    if (trailingNumbers.isEmpty || tokens.isEmpty) return null;

    return _Candidate(
      date: dateMatch.group(1)!,
      description: tokens.join(' '),
      numbers: trailingNumbers,
    );
  }

  static bool _lastColumnIsRunningBalance(List<_Candidate> candidates) {
    final List<_Candidate> multi =
        candidates.where((_Candidate item) => item.numbers.length >= 2).toList(growable: false);
    if (multi.length < 3) return false;

    final List<_Candidate> sample = multi.take(12).toList(growable: false);
    int agreements = 0;
    int comparisons = 0;
    for (int i = 1; i < sample.length; i++) {
      final double? previous = _toDouble(sample[i - 1].numbers.last);
      final double? current = _toDouble(sample[i].numbers.last);
      final double? amount = _toDouble(sample[i].numbers[sample[i].numbers.length - 2]);
      if (previous == null || current == null || amount == null) continue;
      comparisons++;
      final double delta = (current - previous).abs();
      if ((delta - amount.abs()).abs() < 0.02) agreements++;
    }
    if (comparisons == 0) return false;
    return agreements / comparisons >= 0.6;
  }

  static double? _toDouble(String raw) {
    String value = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (value.isEmpty) return null;
    final bool negative = value.startsWith('-') || value.endsWith('-');
    value = value.replaceAll('-', '');
    if (value.contains(',')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      final int dot = value.lastIndexOf('.');
      if (dot >= 0 && value.length - dot - 1 == 3 && value.indexOf('.') == dot) {
        value = value.replaceAll('.', '');
      }
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  static String _canonical(String value) {
    return value
        .toUpperCase()
        .replaceAll('Ç', 'C')
        .replaceAll('Ğ', 'G')
        .replaceAll('İ', 'I')
        .replaceAll('Ö', 'O')
        .replaceAll('Ş', 'S')
        .replaceAll('Ü', 'U');
  }
}

class _Word {
  const _Word(this.text, this.bounds);

  final String text;
  final Rect bounds;
}

class _Line {
  const _Line({
    required this.text,
    required this.pageIndex,
    required this.top,
    required this.words,
  });

  final String text;
  final int pageIndex;
  final double top;
  final List<_Word> words;
}

class _Column {
  const _Column({
    required this.label,
    required this.left,
    required this.right,
    required this.start,
    required this.end,
  });

  factory _Column.fromWords(List<_Word> words) {
    return _Column(
      label: words.map((_Word word) => word.text).join(' '),
      left: words.first.bounds.left,
      right: words.last.bounds.right,
      start: words.first.bounds.left,
      end: words.last.bounds.right,
    );
  }

  final String label;
  final double left;
  final double right;
  final double start;
  final double end;

  _Column withRange(double start, double end) => _Column(
        label: label,
        left: left,
        right: right,
        start: start,
        end: end,
      );
}

class _Candidate {
  const _Candidate({
    required this.date,
    required this.description,
    required this.numbers,
  });

  final String date;
  final String description;
  final List<String> numbers;

  String amountAt(bool lastIsBalance) {
    if (numbers.isEmpty) return '';
    if (numbers.length == 1) return numbers.first;
    return lastIsBalance ? numbers[numbers.length - 2] : numbers.last;
  }
}
