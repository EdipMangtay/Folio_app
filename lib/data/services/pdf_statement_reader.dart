import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Turns a PDF statement into the same row/column grid that CSV and XLSX
/// statements produce, so all of the column mapping, sign handling and summary
/// filtering in [StatementParser] applies unchanged.
///
/// A PDF has no columns, only words at coordinates, and no two banks lay their
/// tables out the same way. So rather than trusting one interpretation, the
/// reader builds several — each plausible header line, at several column-gap
/// widths, plus a header-less line-by-line reading — and scores every one by
/// how many rows actually come out as a date, a description and an amount in
/// separate columns. The best scoring interpretation wins; if none produces a
/// usable row the document is rejected instead of guessed at.
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

  /// Account names that identify the customer's own side of a receipt ledger.
  /// Which side it sits on is what makes the receipt an expense or an income.
  static const List<String> _ownAccountWords = <String>[
    'MEVDUAT',
    'VADESIZ',
    'MUSTERI',
    'KMH',
  ];

  /// Header candidates are limited so a long document cannot turn into a
  /// combinatorial search.
  static const int _maxHeaderCandidates = 8;

  /// Multipliers on the text height used to decide where one header label ends
  /// and the next column begins. Tight layouts need a small gap, airy ones a
  /// large one, and the score decides which reading was right.
  static const List<double> _gapFactors = <double>[0.8, 1.4, 2.2, 3.4];

  static final RegExp _leadingDate = RegExp(r'^(\d{1,2}[./-]\d{1,2}[./-]\d{2,4})\s+');
  static final RegExp _anyDate = RegExp(r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}');
  static final RegExp _money =
      RegExp(r'^\(?-?\d{1,3}(?:[.\s]\d{3})*(?:,\d{1,2})?-?\)?$|^\(?-?\d+(?:[.,]\d{1,2})?-?\)?$');
  static final RegExp _letters = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]{3,}');

  /// Throws when the document holds no usable statement table.
  static List<List<String>> readRows(List<int> bytes) {
    final List<_Line> lines = _extractLines(bytes);
    if (lines.isEmpty) {
      throw const FormatException('No text layer');
    }

    List<List<String>>? best;
    int bestScore = 0;
    for (final List<List<String>> candidate in _interpretations(lines)) {
      final int score = _score(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    if (best == null) throw const FormatException('No statement table found');
    return best;
  }

  static Iterable<List<List<String>>> _interpretations(List<_Line> lines) sync* {
    yield* _columnInterpretations(lines);
    yield _readReceipts(lines);
    yield _readByLines(lines);
  }

  static List<_Line> _extractLines(List<int> bytes) {
    final PdfDocument document = PdfDocument(inputBytes: Uint8List.fromList(bytes));
    try {
      return PdfTextExtractor(document)
          .extractTextLines()
          .map(
            (TextLine line) => _Line(
              text: line.text.trim(),
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

  // ----------------------------------------------------------------- scoring

  /// Counts the rows that would survive [StatementParser]: a date, an amount
  /// and a description, each in its own column. Returns 0 when the header row
  /// itself cannot be mapped, because the parser would reject it anyway.
  static int _score(List<List<String>> rows) {
    if (rows.length < 2) return 0;

    final List<String> header = rows.first.map(_canonical).toList(growable: false);
    final int descriptionColumn =
        header.indexWhere((String cell) => _descriptionWords.any(cell.contains));
    final int moneyColumn = header.indexWhere((String cell) => _moneyWords.any(cell.contains));
    if (descriptionColumn < 0 || moneyColumn < 0 || descriptionColumn == moneyColumn) {
      return 0;
    }

    int usable = 0;
    for (final List<String> row in rows.skip(1)) {
      final int date = row.indexWhere((String cell) => _anyDate.hasMatch(cell));
      if (date < 0) continue;
      final int money = row.lastIndexWhere(_isMoney);
      if (money < 0 || money == date) continue;
      final bool described = <int>[
        for (int i = 0; i < row.length; i++)
          if (i != date && i != money) i,
      ].any((int i) => _letters.hasMatch(row[i]));
      if (described) usable++;
    }
    return usable;
  }

  static bool _isMoney(String cell) {
    final String value = cell.replaceAll(' ', '');
    return value.isNotEmpty && _money.hasMatch(value);
  }

  // ----------------------------------------------------------------- columns

  static Iterable<List<List<String>>> _columnInterpretations(List<_Line> lines) sync* {
    int candidates = 0;
    for (int i = 0; i < lines.length && candidates < _maxHeaderCandidates; i++) {
      if (!_looksLikeHeader(lines[i])) continue;
      candidates++;
      for (final double factor in _gapFactors) {
        final List<_Column> columns = _columnsOf(lines[i], factor);
        if (columns.length < 2) continue;
        yield _distributeAll(lines, headerIndex: i, columns: columns);
      }
    }
  }

  static bool _looksLikeHeader(_Line line) {
    final String canonical = _canonical(line.text);
    return _descriptionWords.any(canonical.contains) &&
        _moneyWords.any(canonical.contains) &&
        line.words.length >= 2;
  }

  static List<List<String>> _distributeAll(
    List<_Line> lines, {
    required int headerIndex,
    required List<_Column> columns,
  }) {
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

  /// Groups the header's words into column labels. Words belonging to one label
  /// (`İşlem` + `Tarihi`) sit close together; a real column break leaves a gap.
  /// [gapFactor] scales what counts as a break.
  static List<_Column> _columnsOf(_Line header, double gapFactor) {
    final List<_Word> words = List<_Word>.from(header.words)
      ..sort((_Word a, _Word b) => a.bounds.left.compareTo(b.bounds.left));

    final double gapThreshold = math.max(
      6,
      words.map((_Word word) => word.bounds.height).reduce(math.max) * gapFactor,
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

  // ---------------------------------------------------------------- receipts

  /// Reads a file of payment receipts (`dekont`) rather than a statement.
  ///
  /// Banks hand these out one transaction at a time and users export them in
  /// batches, so a single PDF can hold dozens back to back. There is no table
  /// spanning the document; each receipt repeats the same skeleton:
  ///
  ///     Tarih      <date>
  ///     Hesap      Borç        Alacak      <- a per-receipt ledger table
  ///     MEVDUAT    + 46,00     0,00        <- the customer's own account
  ///     BKM POS    0,00        + 46,00
  ///     TOPLAM     + 46,00     + 46,00
  ///     Açıklama
  ///     <merchant>
  ///
  /// Whether the customer's account sits on the debit or the credit side is
  /// what makes the transaction an expense or an income, so the receipts are
  /// emitted as a Borç/Alacak grid and the ordinary parser takes it from there.
  static List<List<String>> _readReceipts(List<_Line> lines) {
    final List<List<String>> rows = <List<String>>[
      <String>['Tarih', 'Açıklama', 'Borç', 'Alacak'],
    ];
    for (int i = 0; i < lines.length; i++) {
      if (!_isLedgerHeader(lines[i])) continue;
      final List<String>? receipt = _receiptAt(lines, i);
      if (receipt != null) rows.add(receipt);
    }
    return rows.length > 1 ? rows : const <List<String>>[];
  }

  static bool _isLedgerHeader(_Line line) {
    final String canonical = _canonical(line.text);
    return line.words.length >= 3 &&
        line.words.length <= 5 &&
        canonical.contains('BORC') &&
        canonical.contains('ALACAK');
  }

  static List<String>? _receiptAt(List<_Line> lines, int headerIndex) {
    final List<_Column> columns = _columnsOf(lines[headerIndex], 1.4);
    final int debit = columns.indexWhere((_Column c) => _canonical(c.label).contains('BORC'));
    final int credit = columns.indexWhere((_Column c) => _canonical(c.label).contains('ALACAK'));
    if (debit < 0 || credit < 0) return null;

    // The customer's own account carries the direction. It is conventionally
    // the first row; the named accounts are preferred when present.
    List<String>? ownAccount;
    for (int i = headerIndex + 1; i < lines.length && i <= headerIndex + 8; i++) {
      final String label = _canonical(lines[i].text);
      if (label.startsWith('TOPLAM') || label.startsWith('YAZI ILE')) break;
      final List<String> cells = _distribute(lines[i], columns);
      if (cells.length <= math.max(debit, credit)) continue;
      if (!_isMoney(_stripSign(cells[debit])) && !_isMoney(_stripSign(cells[credit]))) continue;
      ownAccount ??= cells;
      if (_ownAccountWords.any(label.contains)) {
        ownAccount = cells;
        break;
      }
    }
    if (ownAccount == null) return null;

    final String debitCell = _stripSign(ownAccount[debit]);
    final String creditCell = _stripSign(ownAccount[credit]);
    if (_toDouble(debitCell) == null && _toDouble(creditCell) == null) return null;

    final String date = _receiptDate(lines, headerIndex);
    if (date.isEmpty) return null;

    final String description = _receiptDescription(lines, headerIndex);
    if (description.isEmpty) return null;

    return <String>[date, description, debitCell, creditCell];
  }

  /// Ledger cells arrive as `+ 46,00`; the sign marker is a separate word.
  static String _stripSign(String cell) =>
      cell.replaceAll(RegExp(r'^[+\-]\s*'), '').trim();

  static String _receiptDate(List<_Line> lines, int headerIndex) {
    for (int i = headerIndex; i > 0 && i > headerIndex - 60; i--) {
      if (!_canonical(lines[i].text).startsWith('TARIH')) continue;
      final RegExpMatch? here = _anyDate.firstMatch(lines[i].text);
      if (here != null) return here.group(0)!;
      // Some receipts put the label on one line and the value on the next.
      if (i + 1 < lines.length) {
        final RegExpMatch? next = _anyDate.firstMatch(lines[i + 1].text);
        if (next != null) return next.group(0)!;
      }
    }
    return '';
  }

  /// The description follows an `Açıklama` label, sometimes on the same line
  /// and sometimes below it. Continuation lines are recognised by sharing the
  /// value's left edge, which is also what stops the description from running
  /// into the next receipt: that one starts back at the label margin.
  static String _receiptDescription(List<_Line> lines, int headerIndex) {
    for (int i = headerIndex; i < lines.length && i <= headerIndex + 12; i++) {
      if (!_canonical(lines[i].text).startsWith('ACIKLAMA')) continue;

      final List<String> parts = <String>[];
      double? valueLeft;

      final double labelRight = lines[i].words.first.bounds.right;
      final List<_Word> inline = lines[i]
          .words
          .where((_Word word) => word.bounds.left > labelRight + 2)
          .toList(growable: false);
      if (inline.isNotEmpty) {
        valueLeft = inline.first.bounds.left;
        parts.add(inline.map((_Word word) => word.text).join(' '));
      }

      for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
        if (_isLedgerHeader(lines[j])) break;
        final String text = lines[j].text.trim();
        if (text.isEmpty || !_letters.hasMatch(text)) break;
        final double left = lines[j].words.first.bounds.left;
        if (valueLeft == null) {
          valueLeft = left;
        } else if ((left - valueLeft).abs() > 12) {
          break;
        }
        parts.add(text);
      }
      return parts.join(' ').trim();
    }
    return '';
  }

  // ------------------------------------------------------------------- lines

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

  /// Describes what the reader saw, for diagnosing a statement that will not
  /// open. Every digit is masked so the report can be shared safely.
  static String describe(List<int> bytes, {int lineLimit = 30, int lineOffset = 0}) {
    final List<_Line> lines = _extractLines(bytes);
    final StringBuffer report = StringBuffer()
      ..writeln('Satır sayısı: ${lines.length}');

    if (lines.isEmpty) {
      report.writeln('PDF içinde metin katmanı yok (taranmış olabilir).');
      return report.toString();
    }

    final List<int> headerLines = <int>[
      for (int i = 0; i < lines.length; i++)
        if (_looksLikeHeader(lines[i])) i,
    ];
    report.writeln('Başlık adayı satırlar: $headerLines');

    int bestScore = 0;
    List<List<String>>? best;
    for (final List<List<String>> candidate in _interpretations(lines)) {
      final int score = _score(candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    report.writeln('En iyi yorumun puanı: $bestScore');
    if (best != null) {
      report.writeln('Bulunan sütunlar: ${best.first}');
      for (final List<String> row in best.skip(1).take(3)) {
        report.writeln('  örnek satır: ${row.map(_mask).toList()}');
      }
    }

    report.writeln('--- satırlar $lineOffset..${lineOffset + lineLimit} (rakamlar maskeli) ---');
    int index = lineOffset;
    for (final _Line line in lines.skip(lineOffset).take(lineLimit)) {
      report.writeln('$index | ${line.words.length} kelime | ${_mask(line.text)}');
      index++;
    }
    return report.toString();
  }

  static String _mask(String value) => value.replaceAll(RegExp(r'\d'), '#');
}

class _Word {
  const _Word(this.text, this.bounds);

  final String text;
  final Rect bounds;
}

class _Line {
  const _Line({required this.text, required this.words});

  final String text;
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
