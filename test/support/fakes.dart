import 'package:flutter/material.dart';
import 'package:folio_wallet/domain/models/budget_record.dart';
import 'package:folio_wallet/domain/models/subscription_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/models/wallet_snapshot.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';

/// A wallet that records what was written to it instead of touching sqflite.
class FakeWallet extends WalletController {
  FakeWallet([this.initial = const <TransactionRecord>[]]);

  final List<TransactionRecord> initial;
  final List<TransactionRecord> added = <TransactionRecord>[];

  @override
  Future<WalletSnapshot> build() async => WalletSnapshot(
        transactions: initial,
        budgets: const <BudgetRecord>[],
        subscriptions: const <SubscriptionRecord>[],
      );

  @override
  Future<void> addTransaction(TransactionRecord transaction) async {
    added.add(transaction);
  }

  @override
  Future<void> addTransactions(Iterable<TransactionRecord> transactions) async {
    added.addAll(transactions);
  }
}

/// Settings without shared_preferences behind them.
class FakeSettings extends SettingsController {
  bool onboardingCompleted = false;

  @override
  SettingsState build() => const SettingsState(
        themeMode: ThemeMode.light,
        userName: 'Edip',
        hasSeenOnboarding: false,
        privacyLockEnabled: false,
      );

  @override
  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    state = state.copyWith(hasSeenOnboarding: true);
  }
}
