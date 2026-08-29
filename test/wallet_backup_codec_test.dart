import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/data/services/wallet_backup_codec.dart';
import 'package:folio_wallet/domain/models/budget_record.dart';
import 'package:folio_wallet/domain/models/goal_record.dart';
import 'package:folio_wallet/domain/models/subscription_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/models/wallet_snapshot.dart';

void main() {
  test('a wallet backup round-trips transactions, budgets and the name', () {
    final WalletBackup original = WalletBackup(
      exportedAt: DateTime.utc(2026, 8, 29, 12),
      userName: 'Edip',
      snapshot: WalletSnapshot(
        transactions: <TransactionRecord>[
          TransactionRecord(
            id: 'tx-1',
            title: 'Maaş',
            category: 'Maaş',
            amount: 62000,
            date: DateTime.utc(2026, 8, 1),
            type: TransactionType.income,
            source: TransactionSource.manual,
          ),
        ],
        budgets: const <BudgetRecord>[
          BudgetRecord(id: 'b-1', category: 'Market', limitAmount: 4000),
        ],
        subscriptions: const <SubscriptionRecord>[],
        goals: <GoalRecord>[
          const GoalRecord(
            id: 'g-1',
            title: 'Acil durum',
            targetAmount: 20000,
            savedAmount: 1500,
            category: 'Tasarruf',
          ),
        ],
      ),
    );

    final WalletBackup restored = WalletBackupCodec.decode(WalletBackupCodec.encode(original));

    expect(restored.userName, 'Edip');
    expect(restored.snapshot.transactions.single.amount, 62000);
    expect(restored.snapshot.budgets.single.category, 'Market');
    expect(restored.snapshot.goals.single.savedAmount, 1500);
  });

  test('a truncated backup is refused rather than partially applied', () {
    expect(
      () => WalletBackupCodec.decode('{"version":1}'),
      throwsA(isA<FormatException>()),
    );
  });
}
