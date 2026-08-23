import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'merchant_normalizer.dart';

class ReceiptAnalysis {
  const ReceiptAnalysis({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.confidence,
    required this.rawText,
  });

  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final double confidence;
  final String rawText;
}

abstract interface class ReceiptAnalyzer {
  Future<ReceiptAnalysis> analyze(String imagePath);
}

/// On-device receipt recognition. No receipt image is uploaded by this service.
///
/// OCR is intentionally separated from the heuristic parser so a cloud OCR or
/// bank-specific parser can be plugged in later without changing the UI.
class MlKitReceiptAnalyzer implements ReceiptAnalyzer {
  @override
  Future<ReceiptAnalysis> analyze(String imagePath) async {
    final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return ReceiptTextParser.parse(result.text);
    } finally {
      await recognizer.close();
    }
  }
}

class ReceiptTextParser {
  const ReceiptTextParser._();

  static final RegExp _datePattern = RegExp(
    r'\b([0-3]?\d)[./-]([01]?\d)[./-]((?:19|20)?\d{2})\b',
    caseSensitive: false,
  );
  static final RegExp _moneyPattern = RegExp(
    r'(?<!\d)(-?\d{1,3}(?:[.\s]\d{3})*(?:,\d{2})|-?\d+(?:[.,]\d{2}))(?!\d)',
  );

  static const List<String> _merchantNoise = <String>[
    'FIS',
    'FİŞ',
    'TARIH',
    'TARİH',
    'SAAT',
    'VERGI',
    'VERGİ',
    'VKN',
    'KDV',
    'POS',
    'TOPLAM',
    'TUTAR',
    'NAKIT',
    'NAKİT',
    'KREDI',
    'KREDİ',
    'BANKA',
    'TESEKKUR',
    'TEŞEKKÜR',
    'MERSIS',
    'MERSİS',
  ];

  static const List<String> _totalHints = <String>[
    'GENEL TOPLAM',
    'ODENECEK',
    'ÖDENECEK',
    'TOPLAM TUTAR',
    'KART TOPLAM',
    'TOPLAM',
    'TUTAR',
  ];

  static ReceiptAnalysis parse(String rawText) {
    final List<String> lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);

    final String merchant = _findMerchant(lines);
    final double amount = _findAmount(lines);
    final DateTime? parsedDate = _findDate(lines);
    final DateTime date = parsedDate ?? DateTime.now();
    final String category = MerchantNormalizer.categoryFor(merchant);

    double confidence = 0.34;
    if (merchant != 'Bilinmeyen mağaza') confidence += 0.20;
    if (amount > 0) confidence += 0.28;
    if (parsedDate != null) confidence += 0.14;
    if (category != 'Diğer') confidence += 0.04;

    return ReceiptAnalysis(
      merchant: merchant,
      amount: amount,
      date: date,
      category: category,
      confidence: confidence.clamp(0.45, 0.98).toDouble(),
      rawText: rawText,
    );
  }

  static String _findMerchant(List<String> lines) {
    final int merchantScanCount = lines.length < 10 ? lines.length : 10;
    for (final String line in lines.take(merchantScanCount)) {
      final String canonical = _canonical(line);
      if (canonical.length < 3 || canonical.length > 52) continue;
      if (_merchantNoise.any(canonical.contains)) continue;
      if (_datePattern.hasMatch(line)) continue;
      if (_moneyPattern.hasMatch(line) && canonical.replaceAll(RegExp(r'[^A-ZÇĞİÖŞÜ]'), '').length < 3) {
        continue;
      }
      final String cleaned = line
          .replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü0-9 &.\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length >= 3) return MerchantNormalizer.normalize(cleaned);
    }
    return 'Bilinmeyen mağaza';
  }

  static double _findAmount(List<String> lines) {
    final List<double> prioritized = <double>[];
    final List<double> all = <double>[];

    for (final String line in lines) {
      final List<double> values = _moneyPattern
          .allMatches(line)
          .map((RegExpMatch match) => _parseMoney(match.group(0)!))
          .whereType<double>()
          .where((double value) => value > 0 && value < 100000000)
          .toList(growable: false);
      all.addAll(values);

      final String canonical = _canonical(line);
      if (_totalHints.any(canonical.contains)) {
        prioritized.addAll(values);
      }
    }

    if (prioritized.isNotEmpty) return prioritized.reduce(math.max);
    if (all.isNotEmpty) return all.reduce(math.max);
    return 0;
  }

  static DateTime? _findDate(List<String> lines) {
    for (final String line in lines) {
      final RegExpMatch? match = _datePattern.firstMatch(line);
      if (match == null) continue;
      final int day = int.parse(match.group(1)!);
      final int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      try {
        final DateTime result = DateTime(year, month, day);
        if (result.day == day && result.month == month && result.year == year) return result;
      } on ArgumentError {
        continue;
      }
    }
    return null;
  }

  static double? _parseMoney(String raw) {
    String value = raw.replaceAll(' ', '').trim();
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
