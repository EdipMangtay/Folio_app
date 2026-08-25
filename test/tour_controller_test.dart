import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/state/tour_controller.dart';

void main() {
  group('kTourSteps', () {
    test('opens by asking for income, so later stops show a real figure', () {
      expect(kTourSteps.first, isA<TourFormStep>());
    });

    test('every spotlight stop names a tab the shell actually has', () {
      for (final TourStep step in kTourSteps) {
        if (step is TourSpotlightStep) {
          expect(step.tab, inInclusiveRange(0, 3));
        }
      }
    });

    test('visits all four tabs', () {
      final Set<int> tabs = <int>{
        for (final TourStep step in kTourSteps)
          if (step is TourSpotlightStep) step.tab,
      };
      expect(tabs, <int>{0, 1, 2, 3});
    });

    test('every stop says something', () {
      for (final TourStep step in kTourSteps) {
        final String title =
            step is TourFormStep ? step.title : (step as TourSpotlightStep).title;
        final String body =
            step is TourFormStep ? step.body : (step as TourSpotlightStep).body;
        expect(title.trim(), isNotEmpty);
        expect(body.trim(), isNotEmpty);
      }
    });
  });

  group('TourController', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    TourState read() => container.read(tourProvider);
    TourController notifier() => container.read(tourProvider.notifier);

    test('is not running until it is started', () {
      expect(read().running, isFalse);
      expect(read().step, isNull);
    });

    test('starts on the first step', () {
      notifier().start();
      expect(read().running, isTrue);
      expect(read().index, 0);
      expect(read().step, kTourSteps.first);
    });

    test('advances one step at a time', () {
      notifier().start();
      notifier().next();
      expect(read().index, 1);
      expect(read().step, kTourSteps[1]);
    });

    test('next on the last step ends the tour', () {
      notifier().start();
      for (int i = 0; i < kTourSteps.length; i++) {
        notifier().next();
      }
      expect(read().running, isFalse);
      expect(read().step, isNull);
    });

    test('finish ends the tour from anywhere', () {
      notifier().start();
      notifier().next();
      notifier().finish();
      expect(read().running, isFalse);
    });

    test('isLast is only true on the final step', () {
      notifier().start();
      expect(read().isLast, isFalse);
      for (int i = 0; i < kTourSteps.length - 1; i++) {
        notifier().next();
      }
      expect(read().isLast, isTrue);
    });

    test('restarting goes back to the beginning', () {
      notifier().start();
      notifier().next();
      notifier().finish();
      notifier().start();
      expect(read().index, 0);
      expect(read().running, isTrue);
    });
  });
}
