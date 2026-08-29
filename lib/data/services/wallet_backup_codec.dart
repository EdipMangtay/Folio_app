import 'dart:convert';

import '../../domain/models/budget_record.dart';
import '../../domain/models/goal_record.dart';
import '../../domain/models/subscription_record.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/models/wallet_snapshot.dart';

/// Full wallet snapshot the user owns. Folio never stores this on its own
/// servers — it is written to the user's iCloud or Google Drive.
class WalletBackup {
  const WalletBackup({
    required this.exportedAt,
    required this.userName,
    required this.snapshot,
  });

  final DateTime exportedAt;
  final String userName;
  final WalletSnapshot snapshot;
}

abstract final class WalletBackupCodec {
  static const int formatVersion = 1;
  static const String fileName = 'folio-wallet.json';

  static String encode(WalletBackup backup) {
    return jsonEncode(<String, Object?>{
      'version': formatVersion,
      'exportedAt': backup.exportedAt.toIso8601String(),
      'userName': backup.userName,
      'transactions': backup.snapshot.transactions.map((TransactionRecord e) => e.toMap()).toList(),
      'budgets': backup.snapshot.budgets.map((BudgetRecord e) => e.toMap()).toList(),
      'goals': backup.snapshot.goals.map((GoalRecord e) => e.toMap()).toList(),
    });
  }

  static WalletBackup decode(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Yedek okunamadı.');
    }
    final Map<String, Object?> map = _asMap(decoded);
    final Object? version = map['version'];
    if (version is! num || version.toInt() != formatVersion) {
      throw const FormatException('Bu yedek bu Folio sürümüyle açılamıyor.');
    }
    final Object? exportedAt = map['exportedAt'];
    if (exportedAt is! String) {
      throw const FormatException('Yedek okunamadı.');
    }
    return WalletBackup(
      exportedAt: DateTime.parse(exportedAt),
      userName: (map['userName'] as String?) ?? '',
      snapshot: WalletSnapshot(
        transactions: _list(map['transactions']).map(TransactionRecord.fromMap).toList(),
        budgets: _list(map['budgets']).map(BudgetRecord.fromMap).toList(),
        goals: _list(map['goals']).map(GoalRecord.fromMap).toList(),
        subscriptions: const <SubscriptionRecord>[],
      ),
    );
  }

  static Map<String, Object?> _asMap(Map<dynamic, dynamic> raw) {
    return raw.map((dynamic key, dynamic value) => MapEntry(key.toString(), value));
  }

  static List<Map<String, Object?>> _list(Object? raw) {
    if (raw == null) return <Map<String, Object?>>[];
    if (raw is! List) throw const FormatException('Yedek okunamadı.');
    return raw.map((dynamic item) {
      if (item is! Map) throw const FormatException('Yedek okunamadı.');
      return _asMap(item);
    }).toList(growable: false);
  }
}
