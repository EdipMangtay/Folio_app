import 'package:flutter/material.dart';
import 'package:folio_wallet/domain/models/budget_record.dart';
import 'package:folio_wallet/domain/models/goal_record.dart';
import 'package:folio_wallet/domain/models/subscription_record.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/models/wallet_snapshot.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';

/// A wallet that records what was written to it instead of touching sqflite.
class FakeWallet extends WalletController {
  FakeWallet([
    this.initial = const <TransactionRecord>[],
    this.initialBudgets = const <BudgetRecord>[],
    this.initialSubscriptions = const <SubscriptionRecord>[],
    this.initialGoals = const <GoalRecord>[],
  ]);

  final List<TransactionRecord> initial;
  final List<BudgetRecord> initialBudgets;
  final List<SubscriptionRecord> initialSubscriptions;
  final List<GoalRecord> initialGoals;

  final List<TransactionRecord> added = <TransactionRecord>[];
  final List<GoalRecord> savedGoals = <GoalRecord>[];

  @override
  Future<WalletSnapshot> build() async => WalletSnapshot(
        transactions: initial,
        budgets: initialBudgets,
        subscriptions: initialSubscriptions,
        goals: initialGoals,
      );

  @override
  Future<void> addTransaction(TransactionRecord transaction) async {
    added.add(transaction);
  }

  @override
  Future<void> addTransactions(Iterable<TransactionRecord> transactions) async {
    added.addAll(transactions);
  }

  @override
  Future<void> saveGoal(GoalRecord goal) async {
    savedGoals.add(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    savedGoals.removeWhere((GoalRecord g) => g.id == id);
  }
}

/// Settings without shared_preferences behind them.
class FakeSettings extends SettingsController {
  FakeSettings({
    this.hasSeenOnboarding = false,
    this.hideBalances = false,
    this.weeklyNotificationsEnabled = true,
  });

  final bool hasSeenOnboarding;
  final bool hideBalances;
  final bool weeklyNotificationsEnabled;
  bool onboardingCompleted = false;

  @override
  SettingsState build() => SettingsState(
        themeMode: ThemeMode.light,
        userName: 'Edip',
        hasSeenOnboarding: hasSeenOnboarding,
        privacyLockEnabled: false,
        hideBalances: hideBalances,
        weeklyNotificationsEnabled: weeklyNotificationsEnabled,
      );

  @override
  Future<void> setUserName(String value) async {
    state = state.copyWith(userName: value.trim().isEmpty ? 'Edip' : value.trim());
  }

  @override
  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    state = state.copyWith(hasSeenOnboarding: true);
  }

  @override
  Future<void> setHideBalances(bool hide) async {
    state = state.copyWith(hideBalances: hide);
  }

  @override
  Future<void> toggleHideBalances() async {
    state = state.copyWith(hideBalances: !state.hideBalances);
  }

  @override
  Future<void> toggleWeeklyNotifications() async {
    state = state.copyWith(
      weeklyNotificationsEnabled: !state.weeklyNotificationsEnabled,
    );
  }

  @override
  Future<void> setWeeklyNotifications(bool value) async {
    state = state.copyWith(weeklyNotificationsEnabled: value);
  }
}
