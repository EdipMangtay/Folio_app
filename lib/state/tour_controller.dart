import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tour/tour_step.dart';

class TourState {
  const TourState({required this.running, required this.index});

  const TourState.idle()
      : running = false,
        index = 0;

  final bool running;
  final int index;

  TourStep? get step =>
      running && index >= 0 && index < kTourSteps.length ? kTourSteps[index] : null;

  bool get isLast => running && index == kTourSteps.length - 1;

  TourState copyWith({bool? running, int? index}) =>
      TourState(running: running ?? this.running, index: index ?? this.index);
}

final NotifierProvider<TourController, TourState> tourProvider =
    NotifierProvider<TourController, TourState>(TourController.new);

class TourController extends Notifier<TourState> {
  @override
  TourState build() => const TourState.idle();

  void start() => state = const TourState(running: true, index: 0);

  /// Moves on, ending the tour once the last stop has been seen.
  void next() {
    if (!state.running) return;
    final int nextIndex = state.index + 1;
    if (nextIndex >= kTourSteps.length) {
      finish();
    } else {
      state = state.copyWith(index: nextIndex);
    }
  }

  void finish() => state = const TourState.idle();
}
