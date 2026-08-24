import '../../domain/models/transaction_record.dart';

class ImportSplit {
  const ImportSplit({required this.fresh, required this.duplicates});

  final List<TransactionRecord> fresh;
  final List<TransactionRecord> duplicates;
}

/// Keeps a statement from being imported twice.
///
/// Matching is count aware: if the file holds two identical rows and only one
/// is already stored, the second one is still imported. Only previously
/// imported statement rows are considered, so a manually entered coffee never
/// blocks the same charge arriving from the bank.
abstract final class ImportDeduplicator {
  static ImportSplit split({
    required List<TransactionRecord> incoming,
    required List<TransactionRecord> existing,
  }) {
    final Map<String, int> available = <String, int>{};
    for (final TransactionRecord record in existing) {
      if (record.source != TransactionSource.statement) continue;
      available.update(_key(record), (int value) => value + 1, ifAbsent: () => 1);
    }

    final List<TransactionRecord> fresh = <TransactionRecord>[];
    final List<TransactionRecord> duplicates = <TransactionRecord>[];
    for (final TransactionRecord record in incoming) {
      final String key = _key(record);
      final int remaining = available[key] ?? 0;
      if (remaining > 0) {
        available[key] = remaining - 1;
        duplicates.add(record);
      } else {
        fresh.add(record);
      }
    }

    return ImportSplit(fresh: fresh, duplicates: duplicates);
  }

  static String _key(TransactionRecord record) {
    final String day =
        '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
    final String name = (record.merchant ?? record.title).trim().toLowerCase();
    return '$day|$name|${record.amount.toStringAsFixed(2)}|${record.type.name}';
  }
}
