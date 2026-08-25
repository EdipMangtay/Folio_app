import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/analytics/month_scope.dart';
import '../domain/models/wallet_snapshot.dart';
import 'wallet_controller.dart';

/// The month every analytics surface is currently reporting on.
///
/// Shared rather than per-screen so stepping back to a statement's period on
/// the dashboard keeps the analysis, budgets and monthly report describing the
/// same month.
final NotifierProvider<SelectedMonthController, DateTime> selectedMonthProvider =
    NotifierProvider<SelectedMonthController, DateTime>(SelectedMonthController.new);

class SelectedMonthController extends Notifier<DateTime> {
  /// Whether the opening month has been worked out from real wallet data.
  ///
  /// The wallet loads asynchronously, so the first value is a guess made
  /// before the transactions exist. It is corrected once, when they arrive.
  /// After that the month belongs to the user and nothing moves it on its own.
  bool _resolved = false;

  @override
  DateTime build() {
    ref.listen<AsyncValue<WalletSnapshot>>(walletProvider, (
      AsyncValue<WalletSnapshot>? previous,
      AsyncValue<WalletSnapshot> next,
    ) {
      final WalletSnapshot? snapshot = next.value;
      if (_resolved || snapshot == null) return;
      _resolved = true;
      state = MonthScope.initialMonth(snapshot.transactions, now: DateTime.now());
    });

    final WalletSnapshot? snapshot = ref.read(walletProvider).value;
    if (snapshot != null) {
      _resolved = true;
      return MonthScope.initialMonth(snapshot.transactions, now: DateTime.now());
    }
    return MonthScope.monthOf(DateTime.now());
  }

  void select(DateTime month) {
    _resolved = true;
    state = MonthScope.monthOf(month);
  }

  /// Moves [months] months forward, or back when negative.
  void step(int months) {
    _resolved = true;
    state = DateTime(state.year, state.month + months);
  }

  void reset() => select(DateTime.now());
}
