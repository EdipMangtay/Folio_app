import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/tour/tour_anchor.dart';

void main() {
  testWidgets('an anchored widget can be measured by its target name', (
    WidgetTester tester,
  ) async {
    late TourTargetRegistry registry;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            registry = ref.watch(tourTargetRegistryProvider);
            return const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: TourAnchor(
                    target: TourTarget.analyticsTab,
                    child: SizedBox(width: 80, height: 40),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final Rect? rect = registry.rectOf(TourTarget.analyticsTab);
    expect(rect, isNotNull);
    expect(rect!.width, 80);
    expect(rect.height, 40);
  });

  testWidgets('an unregistered target measures as null', (WidgetTester tester) async {
    late TourTargetRegistry registry;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            registry = ref.watch(tourTargetRegistryProvider);
            return const MaterialApp(home: Scaffold(body: SizedBox()));
          },
        ),
      ),
    );
    await tester.pump();

    expect(registry.rectOf(TourTarget.profileTab), isNull);
  });

  testWidgets('a removed anchor stops being measurable', (WidgetTester tester) async {
    late TourTargetRegistry registry;

    Widget build({required bool show}) {
      return ProviderScope(
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            registry = ref.watch(tourTargetRegistryProvider);
            return MaterialApp(
              home: Scaffold(
                body: show
                    ? const TourAnchor(
                        target: TourTarget.homeTab,
                        child: SizedBox(width: 10, height: 10),
                      )
                    : const SizedBox(),
              ),
            );
          },
        ),
      );
    }

    await tester.pumpWidget(build(show: true));
    await tester.pump();
    expect(registry.rectOf(TourTarget.homeTab), isNotNull);

    await tester.pumpWidget(build(show: false));
    await tester.pump();
    expect(registry.rectOf(TourTarget.homeTab), isNull);
  });
}
