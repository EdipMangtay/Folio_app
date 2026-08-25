# Guided In-App Tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four-slide onboarding screen with a tour that runs inside the app, driving the tabs itself and pointing at the control it is describing.

**Architecture:** A Riverpod `TourController` owns the step index. A registry maps a `TourTarget` enum to the `GlobalKey` of whichever widget currently represents it, so the phone dock and the tablet rail register the same targets. `AppShell` — the widget that already owns `navigationShell` — puts a `TourOverlay` in a `Stack` above the tabs; the overlay measures the target through the registry and paints a scrim with that rect cut out.

**Tech Stack:** Flutter, `flutter_riverpod` 3.4.2, `go_router`, `uuid`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-25-guided-tour-design.md`

## Global Constraints

- All user-facing copy is Turkish.
- No new package dependencies.
- Explicit types on declarations, matching the surrounding code (`final String x = ...`, `<Widget>[...]`).
- Money parsing goes through `Formatters.parseMoneyInput`; money display through `Formatters.money`.
- Motion uses `FolioMotion` tokens and is skipped entirely when `FolioMotion.reduce(context)` is true.
- Interactive targets are at least 44pt.
- Colours come from `AppColors.*(theme.brightness)`, never raw hex.
- `flutter analyze` must report no errors or warnings. The 6 pre-existing `info` items in untouched files are the accepted baseline.
- Tests use the fakes in `test/support/fakes.dart` (`FakeWallet`, `FakeSettings`). `ProviderScope(overrides: [...])` takes an inferred list — `Override` is not exported by flutter_riverpod 3.
- `pumpAndSettle` hangs wherever `MoneyPulse` is mounted; pump fixed durations instead.
- Screens under test need a `Scaffold` ancestor — in the app that comes from `AppShell`.

---

### Task 1: Tour steps and controller

**Files:**
- Create: `lib/domain/tour/tour_step.dart`
- Create: `lib/state/tour_controller.dart`
- Test: `test/tour_controller_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum TourTarget { homeTab, transactionsTab, addButton, analyticsTab, profileTab }`
  - `sealed class TourStep { const TourStep(); }`
  - `class TourFormStep extends TourStep { const TourFormStep({required String title, required String body}); final String title; final String body; }`
  - `class TourSpotlightStep extends TourStep { const TourSpotlightStep({required int tab, required TourTarget target, required String title, required String body}); final int tab; final TourTarget target; final String title; final String body; }`
  - `const List<TourStep> kTourSteps`
  - `class TourState { const TourState({required bool running, required int index}); final bool running; final int index; TourStep? get step; bool get isLast; TourState copyWith({bool? running, int? index}); }`
  - `final NotifierProvider<TourController, TourState> tourProvider`
  - `TourController.start()`, `.next()`, `.finish()`

- [ ] **Step 1: Write the failing test**

`test/tour_controller_test.dart`:

```dart
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
        final String title = step is TourFormStep ? step.title : (step as TourSpotlightStep).title;
        final String body = step is TourFormStep ? step.body : (step as TourSpotlightStep).body;
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tour_controller_test.dart`
Expected: FAIL — `Error: Not found: 'package:folio_wallet/domain/tour/tour_step.dart'`

- [ ] **Step 3: Write the step model**

`lib/domain/tour/tour_step.dart`:

```dart
/// Something the tour can point at.
///
/// Named rather than keyed so the phone dock and the tablet rail can offer the
/// same targets without the tour knowing which shell is on screen.
enum TourTarget { homeTab, transactionsTab, addButton, analyticsTab, profileTab }

sealed class TourStep {
  const TourStep();
}

/// A stop that asks for something instead of pointing at something.
class TourFormStep extends TourStep {
  const TourFormStep({required this.title, required this.body});

  final String title;
  final String body;
}

/// A stop that highlights one control and says what it is for.
class TourSpotlightStep extends TourStep {
  const TourSpotlightStep({
    required this.tab,
    required this.target,
    required this.title,
    required this.body,
  });

  /// The branch index the shell must be showing before this stop makes sense.
  final int tab;
  final TourTarget target;
  final String title;
  final String body;
}

/// Income comes first on purpose: a fresh install has an empty wallet, so a
/// tour that asked for it last would spend every stop explaining blank screens.
const List<TourStep> kTourSteps = <TourStep>[
  TourFormStep(
    title: 'Gelirini gir.',
    body: 'Tek bir gelir kaydı yeter. Turun geri kalanını kendi rakamınla '
        'gezersin, sonra istediğin zaman değiştirebilirsin.',
  ),
  TourSpotlightStep(
    tab: 0,
    target: TourTarget.homeTab,
    title: 'Ana',
    body: 'Seçili dönemin özeti: ne harcadın, ne kazandın, sende ne kaldı.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.transactionsTab,
    title: 'İşlemler',
    body: 'Her kayıt burada. Filtreleyebilir, düzeltebilir, silebilirsin.',
  ),
  TourSpotlightStep(
    tab: 1,
    target: TourTarget.addButton,
    title: 'Ekle',
    body: 'Elle gelir ya da gider ekle, fiş tara, banka ekstreni aktar.',
  ),
  TourSpotlightStep(
    tab: 2,
    target: TourTarget.analyticsTab,
    title: 'Analiz',
    body: 'Dönemin tüm görünümü. Üstteki dönem düğmesi geçmiş ayları açar — '
        'ekstre çoğunlukla kapanmış bir dönemi kapsar, oraya oradan geçersin.',
  ),
  TourSpotlightStep(
    tab: 3,
    target: TourTarget.profileTab,
    title: 'Profil',
    body: 'Bütçeler, abonelikler ve verini dışa aktarma burada.',
  ),
];
```

- [ ] **Step 4: Write the controller**

`lib/state/tour_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tour/tour_step.dart';

class TourState {
  const TourState({required this.running, required this.index});

  const TourState.idle() : running = false, index = 0;

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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/tour_controller_test.dart`
Expected: PASS, 11 tests

- [ ] **Step 6: Verify analyze is clean**

Run: `flutter analyze`
Expected: no errors, no warnings

- [ ] **Step 7: Commit**

```bash
git add lib/domain/tour/tour_step.dart lib/state/tour_controller.dart test/tour_controller_test.dart
git commit -m "Add the tour's steps and the controller that walks them"
```

---

### Task 2: Target registry

**Files:**
- Create: `lib/presentation/tour/tour_anchor.dart`
- Test: `test/tour_anchor_test.dart`

**Interfaces:**
- Consumes: `TourTarget` from Task 1.
- Produces:
  - `class TourTargetRegistry { void register(TourTarget target, GlobalKey key); void unregister(TourTarget target, GlobalKey key); Rect? rectOf(TourTarget target); }`
  - `final Provider<TourTargetRegistry> tourTargetRegistryProvider`
  - `class TourAnchor extends ConsumerStatefulWidget { const TourAnchor({required TourTarget target, required Widget child, super.key}); }`

- [ ] **Step 1: Write the failing test**

`test/tour_anchor_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tour_anchor_test.dart`
Expected: FAIL — `Error: Not found: 'package:folio_wallet/presentation/tour/tour_anchor.dart'`

- [ ] **Step 3: Write the registry and anchor**

`lib/presentation/tour/tour_anchor.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/tour/tour_step.dart';

/// Where the tour finds the thing it is pointing at.
///
/// Widgets announce themselves by name, so the phone dock and the tablet rail
/// can both offer `analyticsTab` and the tour never learns which shell is on
/// screen. Only one of them is mounted at a time.
class TourTargetRegistry {
  final Map<TourTarget, GlobalKey> _keys = <TourTarget, GlobalKey>{};

  void register(TourTarget target, GlobalKey key) => _keys[target] = key;

  /// Only clears the entry if this key is still the one registered, so a
  /// rebuild that registers the replacement first is not undone by the old
  /// widget's dispose.
  void unregister(TourTarget target, GlobalKey key) {
    if (identical(_keys[target], key)) _keys.remove(target);
  }

  /// The target's position in global coordinates, or null when it is not on
  /// screen or has not been laid out yet.
  Rect? rectOf(TourTarget target) {
    final BuildContext? context = _keys[target]?.currentContext;
    if (context == null) return null;
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }
}

final Provider<TourTargetRegistry> tourTargetRegistryProvider =
    Provider<TourTargetRegistry>((Ref ref) => TourTargetRegistry());

/// Marks its child as the thing the tour means by [target].
class TourAnchor extends ConsumerStatefulWidget {
  const TourAnchor({required this.target, required this.child, super.key});

  final TourTarget target;
  final Widget child;

  @override
  ConsumerState<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends ConsumerState<TourAnchor> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    ref.read(tourTargetRegistryProvider).register(widget.target, _key);
  }

  @override
  void dispose() {
    ref.read(tourTargetRegistryProvider).unregister(widget.target, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/tour_anchor_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/tour/tour_anchor.dart test/tour_anchor_test.dart
git commit -m "Let widgets announce themselves as things the tour can point at"
```

---

### Task 3: Extract the income card

**Files:**
- Create: `lib/presentation/widgets/income_entry_card.dart`
- Test: `test/income_entry_card_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `class IncomeEntryCard extends StatefulWidget { const IncomeEntryCard({required Future<void> Function(double amount, String source) onSubmit, required VoidCallback onSkip, super.key}); }`

The validation is lifted verbatim from `OnboardingScreen`, which Task 6 deletes: refusals appear under the field, never as a snackbar over the buttons.

- [ ] **Step 1: Write the failing test**

`test/income_entry_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/presentation/widgets/income_entry_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required void Function(double, String) onSubmit,
    required VoidCallback onSkip,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: IncomeEntryCard(
            onSubmit: (double amount, String source) async => onSubmit(amount, source),
            onSkip: onSkip,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hands over a parsed amount and source', (WidgetTester tester) async {
    double? amount;
    String? source;
    await pump(
      tester,
      onSubmit: (double a, String s) {
        amount = a;
        source = s;
      },
      onSkip: () {},
    );

    await tester.enterText(find.byType(TextField).at(0), '62.000');
    await tester.enterText(find.byType(TextField).at(1), 'Freelance iş');
    await tester.pump();
    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(amount, 62000);
    expect(source, 'Freelance iş');
  });

  testWidgets('refuses an empty amount under the field, not over the buttons', (
    WidgetTester tester,
  ) async {
    bool submitted = false;
    await pump(tester, onSubmit: (_, __) => submitted = true, onSkip: () {});

    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Bir tutar gir.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets('refuses an unreadable amount', (WidgetTester tester) async {
    bool submitted = false;
    await pump(tester, onSubmit: (_, __) => submitted = true, onSkip: () {});

    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.pump();
    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Geçerli bir tutar gir.'), findsOneWidget);
  });

  testWidgets('refuses a negative amount', (WidgetTester tester) async {
    bool submitted = false;
    await pump(tester, onSubmit: (_, __) => submitted = true, onSkip: () {});

    await tester.enterText(find.byType(TextField).first, '-500');
    await tester.pump();
    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();

    expect(submitted, isFalse);
  });

  testWidgets('typing clears the refusal', (WidgetTester tester) async {
    await pump(tester, onSubmit: (_, __) {}, onSkip: () {});

    await tester.tap(find.text('Kaydet ve devam et'));
    await tester.pump();
    expect(find.text('Bir tutar gir.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.pump();
    expect(find.text('Bir tutar gir.'), findsNothing);
  });

  testWidgets('skipping reports a skip and submits nothing', (WidgetTester tester) async {
    bool skipped = false;
    bool submitted = false;
    await pump(tester, onSubmit: (_, __) => submitted = true, onSkip: () => skipped = true);

    await tester.tap(find.text('Şimdilik geç'));
    await tester.pump();

    expect(skipped, isTrue);
    expect(submitted, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/income_entry_card_test.dart`
Expected: FAIL — `Error: Not found: 'package:folio_wallet/presentation/widgets/income_entry_card.dart'`

- [ ] **Step 3: Write the card**

`lib/presentation/widgets/income_entry_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import 'premium_surface.dart';

/// Asks for one income figure.
///
/// A refusal appears under the field it is about. A snackbar sits at the bottom
/// of the screen, which is where the skip control lives — it hid the button it
/// was telling the user to press.
class IncomeEntryCard extends StatefulWidget {
  const IncomeEntryCard({required this.onSubmit, required this.onSkip, super.key});

  /// Called with a positive amount and the source the user typed, which may be
  /// empty. The card stays busy until this completes.
  final Future<void> Function(double amount, String source) onSubmit;

  final VoidCallback onSkip;

  @override
  State<IncomeEntryCard> createState() => _IncomeEntryCardState();
}

class _IncomeEntryCardState extends State<IncomeEntryCard> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final bool blank = _amountController.text.trim().isEmpty;
    final double? amount = Formatters.parseMoneyInput(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = blank ? 'Bir tutar gir.' : 'Geçerli bir tutar gir.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    await widget.onSubmit(amount, _sourceController.text.trim());
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: PremiumSurface(
        elevated: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Aylık gelirin', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              style: theme.textTheme.headlineSmall,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '₺',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            Text('Kaynak', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _sourceController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Maaş'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Kaydet ve devam et'),
            ),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: _busy ? null : widget.onSkip,
                child: const Text('Şimdilik geç'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`AppSpacing` is imported for consistency with sibling widgets; if analyze reports it unused, remove that import.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/income_entry_card_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/income_entry_card.dart test/income_entry_card_test.dart
git commit -m "Extract the income form so the tour can ask for it"
```

---

### Task 4: The overlay

**Files:**
- Create: `lib/presentation/tour/tour_overlay.dart`
- Test: `test/tour_overlay_test.dart`

**Interfaces:**
- Consumes: `TourStep`/`TourFormStep`/`TourSpotlightStep` (Task 1), `TourTargetRegistry` (Task 2), `IncomeEntryCard` (Task 3).
- Produces: `class TourOverlay extends StatelessWidget { const TourOverlay({required TourStep step, required Rect? highlight, required bool isLast, required VoidCallback onNext, required VoidCallback onSkip, required Future<void> Function(double amount, String source) onIncome, super.key}); }`

The overlay is told the rect; it does not measure. Measuring belongs to Task 5, which knows when the tab has settled.

- [ ] **Step 1: Write the failing test**

`test/tour_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/tour/tour_overlay.dart';
import 'package:folio_wallet/presentation/widgets/income_entry_card.dart';

const TourSpotlightStep _spot = TourSpotlightStep(
  tab: 2,
  target: TourTarget.analyticsTab,
  title: 'Analiz',
  body: 'Dönemin tüm görünümü.',
);

Future<void> _pump(
  WidgetTester tester, {
  required TourStep step,
  Rect? highlight,
  bool isLast = false,
  VoidCallback? onNext,
  VoidCallback? onSkip,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: TourOverlay(
          step: step,
          highlight: highlight,
          isLast: isLast,
          onNext: onNext ?? () {},
          onSkip: onSkip ?? () {},
          onIncome: (double a, String s) async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a spotlight stop shows its title and body', (WidgetTester tester) async {
    await _pump(tester, step: _spot, highlight: const Rect.fromLTWH(10, 800, 80, 50));

    expect(find.text('Analiz'), findsOneWidget);
    expect(find.text('Dönemin tüm görünümü.'), findsOneWidget);
  });

  testWidgets('İleri and Geç are real, reachable buttons', (WidgetTester tester) async {
    int next = 0;
    int skip = 0;
    await _pump(
      tester,
      step: _spot,
      highlight: const Rect.fromLTWH(10, 800, 80, 50),
      onNext: () => next++,
      onSkip: () => skip++,
    );

    await tester.tap(find.text('İleri'));
    await tester.tap(find.text('Geç'));
    await tester.pump();

    expect(next, 1);
    expect(skip, 1);
    expect(tester.getSize(find.widgetWithText(FilledButton, 'İleri')).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('the last stop offers Bitir instead of İleri', (WidgetTester tester) async {
    await _pump(
      tester,
      step: _spot,
      highlight: const Rect.fromLTWH(10, 800, 80, 50),
      isLast: true,
    );

    expect(find.text('Bitir'), findsOneWidget);
    expect(find.text('İleri'), findsNothing);
  });

  testWidgets('a stop with no measurable target still says its piece', (
    WidgetTester tester,
  ) async {
    // A missing highlight is a worse tour, not a crash.
    await _pump(tester, step: _spot);

    expect(find.text('Analiz'), findsOneWidget);
    expect(find.text('İleri'), findsOneWidget);
  });

  testWidgets('the form stop shows the income card, not a spotlight', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      step: const TourFormStep(title: 'Gelirini gir.', body: 'Tek bir kayıt yeter.'),
    );

    expect(find.byType(IncomeEntryCard), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsOneWidget);
  });

  testWidgets('the scrim swallows taps meant for what is underneath', (
    WidgetTester tester,
  ) async {
    bool tappedBehind = false;
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              GestureDetector(
                onTap: () => tappedBehind = true,
                child: const SizedBox.expand(child: ColoredBox(color: Colors.white)),
              ),
              TourOverlay(
                step: _spot,
                highlight: const Rect.fromLTWH(10, 800, 80, 50),
                isLast: false,
                onNext: () {},
                onSkip: () {},
                onIncome: (double a, String s) async {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    expect(tappedBehind, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tour_overlay_test.dart`
Expected: FAIL — `Error: Not found: 'package:folio_wallet/presentation/tour/tour_overlay.dart'`

- [ ] **Step 3: Write the overlay**

`lib/presentation/tour/tour_overlay.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/motion/folio_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/tour/tour_step.dart';
import '../widgets/income_entry_card.dart';
import '../widgets/premium_surface.dart';

/// Draws one stop of the tour: the screen dimmed, the target cut out of the
/// dimming, and a bubble saying what that control is for.
///
/// It is told where the target is rather than measuring it, because only the
/// shell knows when a tab change has settled enough to measure.
class TourOverlay extends StatelessWidget {
  const TourOverlay({
    required this.step,
    required this.highlight,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    required this.onIncome,
    super.key,
  });

  final TourStep step;

  /// Global rect of the control being described, or null when it could not be
  /// measured — the bubble then appears without a cut-out.
  final Rect? highlight;

  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Future<void> Function(double amount, String source) onIncome;

  static const double _pad = 8;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Rect? cut = highlight?.inflate(_pad);

    final Widget content = Stack(
      children: <Widget>[
        // Blocks everything underneath: the tour drives, so a stray tap must
        // not take the user somewhere the tour has not reached.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(
              painter: _ScrimPainter(
                cutout: cut,
                color: Colors.black.withValues(alpha: 0.62),
                ring: AppColors.accent(theme.brightness),
              ),
            ),
          ),
        ),
        if (step is TourFormStep)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _FormBubble(
                step: step as TourFormStep,
                onIncome: onIncome,
                onSkip: onSkip,
              ),
            ),
          )
        else
          _SpotlightBubble(
            step: step as TourSpotlightStep,
            cutout: cut,
            isLast: isLast,
            onNext: onNext,
            onSkip: onSkip,
          ),
      ],
    );

    final Widget scoped = Semantics(
      container: true,
      explicitChildNodes: true,
      child: content,
    );

    if (FolioMotion.reduce(context)) return scoped;
    return AnimatedOpacity(
      opacity: 1,
      duration: FolioMotion.standard,
      curve: FolioMotion.enter,
      child: scoped,
    );
  }
}

/// Dims everything except the cut-out, and rings the cut-out so the highlight
/// is a shape and not only a difference in brightness.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.cutout, required this.color, required this.ring});

  final Rect? cutout;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset.zero & size;
    final Paint scrim = Paint()..color = color;

    if (cutout == null) {
      canvas.drawRect(full, scrim);
      return;
    }

    final RRect hole = RRect.fromRectAndRadius(
      cutout!,
      const Radius.circular(AppSpacing.radiusMd),
    );
    canvas.saveLayer(full, Paint());
    canvas.drawRect(full, scrim);
    canvas.drawRRect(hole, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.cutout != cutout || oldDelegate.color != color || oldDelegate.ring != ring;
}

class _SpotlightBubble extends StatelessWidget {
  const _SpotlightBubble({
    required this.step,
    required this.cutout,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final TourSpotlightStep step;
  final Rect? cutout;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    // Sit on whichever side of the target has room; default to the lower half
    // of the screen when there is nothing to sit beside.
    final bool above = cutout != null && cutout!.center.dy > screen.height / 2;

    return Positioned(
      left: 20,
      right: 20,
      top: above ? null : (cutout?.bottom ?? screen.height * 0.35) + 16,
      bottom: above ? screen.height - cutout!.top + 16 : null,
      child: _Bubble(
        title: step.title,
        body: step.body,
        primaryLabel: isLast ? 'Bitir' : 'İleri',
        onPrimary: onNext,
        onSkip: onSkip,
      ),
    );
  }
}

class _FormBubble extends StatelessWidget {
  const _FormBubble({required this.step, required this.onIncome, required this.onSkip});

  final TourFormStep step;
  final Future<void> Function(double amount, String source) onIncome;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          step.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          step.body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        IncomeEntryCard(onSubmit: onIncome, onSkip: onSkip),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              SizedBox(
                height: 44,
                child: TextButton(onPressed: onSkip, child: const Text('Geç')),
              ),
              const Spacer(),
              SizedBox(
                height: 44,
                child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/tour_overlay_test.dart`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/tour/tour_overlay.dart test/tour_overlay_test.dart
git commit -m "Draw a tour stop: dim the screen, cut out the target, say what it does"
```

---

### Task 5: Drive the tour from the shell

**Files:**
- Modify: `lib/presentation/shell/app_shell.dart`
- Test: `test/tour_shell_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: `AppShell` becomes `ConsumerStatefulWidget`; the dock's four nav items and the add button are wrapped in `TourAnchor`; the tablet rail's four icons register the same four tab targets.

`AppShell` gains `onIncome`, which writes the income transaction through `walletProvider` exactly as the deleted onboarding screen did: `TransactionType.income`, `TransactionSource.manual`, dated now, titled by the source or `Maaş`, `paymentLabel: AppConstants.defaultIncomeLabel`, and a category matched against `AppConstants.incomeCategories` falling back to `Maaş`.

- [ ] **Step 1: Write the failing test**

`test/tour_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/domain/models/transaction_record.dart';
import 'package:folio_wallet/domain/tour/tour_step.dart';
import 'package:folio_wallet/presentation/shell/app_shell.dart';
import 'package:folio_wallet/presentation/tour/tour_overlay.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/tour_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

late FakeWallet wallet;
late FakeSettings settings;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Boots the real shell over four stand-in branch screens.
Future<GoRouter> _open(WidgetTester tester, {bool seen = false}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  wallet = FakeWallet();
  settings = FakeSettings(hasSeenOnboarding: seen);

  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      StatefulShellRoute(
        builder: (BuildContext c, GoRouterState s, StatefulNavigationShell n) => n,
        navigatorContainerBuilder: (
          BuildContext c,
          StatefulNavigationShell n,
          List<Widget> children,
        ) =>
            AppShell(navigationShell: n, children: children),
        branches: <StatefulShellBranch>[
          for (final String name in <String>['Ana', 'İşlemler', 'Analiz', 'Profil'])
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: name == 'Ana' ? '/' : '/${name.toLowerCase()}',
                  builder: (BuildContext c, GoRouterState s) =>
                      Center(child: Text('$name ekranı')),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletProvider.overrideWith(() => wallet),
        settingsProvider.overrideWith(() => settings),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await _settle(tester);
  return router;
}

Future<void> _advance(WidgetTester tester) async {
  final Finder next = find.text('İleri');
  await tester.tap(next.evaluate().isEmpty ? find.text('Bitir') : next);
  await _settle(tester);
}

void main() {
  testWidgets('a first run opens the tour on the income step', (WidgetTester tester) async {
    await _open(tester);

    expect(find.byType(TourOverlay), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsOneWidget);
  });

  testWidgets('a later run does not start the tour', (WidgetTester tester) async {
    await _open(tester, seen: true);
    expect(find.byType(TourOverlay), findsNothing);
  });

  testWidgets('saving income stores one record and moves on', (WidgetTester tester) async {
    await _open(tester);

    await tester.enterText(find.byType(TextField).first, '62000');
    await _settle(tester);
    await tester.tap(find.text('Kaydet ve devam et'));
    await _settle(tester);

    expect(wallet.added.length, 1);
    expect(wallet.added.single.type, TransactionType.income);
    expect(wallet.added.single.amount, 62000);
    expect(find.text('Ana'), findsWidgets);
  });

  testWidgets('skipping income stores nothing and still moves on', (
    WidgetTester tester,
  ) async {
    await _open(tester);

    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    expect(wallet.added, isEmpty);
    expect(find.byType(TourOverlay), findsOneWidget);
    expect(find.text('Gelirini gir.'), findsNothing);
  });

  testWidgets('each stop leaves the shell on the tab it declares', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    for (int i = 1; i < kTourSteps.length; i++) {
      final TourSpotlightStep step = kTourSteps[i] as TourSpotlightStep;
      final String screen = <String>['Ana', 'İşlemler', 'Analiz', 'Profil'][step.tab];
      expect(
        find.text('$screen ekranı'),
        findsOneWidget,
        reason: '${step.title} adımı ${step.tab}. sekmede olmalıydı',
      );
      await _advance(tester);
    }
  });

  testWidgets('walking to the end closes the tour and records it as seen', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    for (int i = 1; i < kTourSteps.length; i++) {
      await _advance(tester);
    }

    expect(find.byType(TourOverlay), findsNothing);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('Geç ends the tour at any point and records it as seen', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    await tester.tap(find.text('Geç'));
    await _settle(tester);

    expect(find.byType(TourOverlay), findsNothing);
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets('the highlight lands on the control the step names', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await _settle(tester);

    // Step 1 points at the home tab.
    final TourOverlay overlay = tester.widget<TourOverlay>(find.byType(TourOverlay));
    final Rect tabRect = tester.getRect(find.bySemanticsLabel('Ana').first);
    expect(overlay.highlight, isNotNull);
    expect((overlay.highlight!.center - tabRect.center).distance, lessThan(2));
  });
}
```

- [ ] **Step 2: Extend the settings fake to take a starting flag**

In `test/support/fakes.dart`, replace the `FakeSettings` class with:

```dart
/// Settings without shared_preferences behind them.
class FakeSettings extends SettingsController {
  FakeSettings({this.hasSeenOnboarding = false});

  final bool hasSeenOnboarding;
  bool onboardingCompleted = false;

  @override
  SettingsState build() => SettingsState(
        themeMode: ThemeMode.light,
        userName: 'Edip',
        hasSeenOnboarding: hasSeenOnboarding,
        privacyLockEnabled: false,
      );

  @override
  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    state = state.copyWith(hasSeenOnboarding: true);
  }
}
```

Existing call sites use `FakeSettings.new` or `FakeSettings()`, both of which still work.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/tour_shell_test.dart`
Expected: FAIL — `TourOverlay` is never found, because nothing mounts it yet.

- [ ] **Step 4: Turn AppShell into a ConsumerStatefulWidget that runs the tour**

In `lib/presentation/shell/app_shell.dart`, add these imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/tour/tour_step.dart';
import '../../state/settings_controller.dart';
import '../../state/tour_controller.dart';
import '../../state/wallet_controller.dart';
import '../tour/tour_anchor.dart';
import '../tour/tour_overlay.dart';
```

Replace the `AppShell` class declaration and `build` with:

```dart
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, required this.children, super.key});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// The target rect for the current stop, measured after its tab has settled.
  Rect? _highlight;
  int _measuredFor = -1;

  int get _index => widget.navigationShell.currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool seen = ref.read(settingsProvider).hasSeenOnboarding;
      if (!seen) ref.read(tourProvider.notifier).start();
    });
  }

  void _goBranch(int index) {
    if (index != _index) HapticFeedback.selectionClick();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  /// Puts the shell on the stop's tab, waits for the switch to settle, then
  /// measures. FolioTabSwitcher animates over FolioMotion.tab, and a rect read
  /// before that finishes belongs to the outgoing screen.
  void _prepare(TourState tour) {
    final TourStep? step = tour.step;
    if (step is! TourSpotlightStep) {
      if (_highlight != null || _measuredFor != tour.index) {
        _measuredFor = tour.index;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _highlight = null);
        });
      }
      return;
    }
    if (_measuredFor == tour.index) return;
    _measuredFor = tour.index;

    if (_index != step.tab) _goBranch(step.tab);

    Future<void>.delayed(FolioMotion.tab + const Duration(milliseconds: 32), () {
      if (!mounted) return;
      final Rect? rect = ref.read(tourTargetRegistryProvider).rectOf(step.target);
      setState(() => _highlight = rect);
    });
  }

  Future<void> _finishTour() async {
    ref.read(tourProvider.notifier).finish();
    await ref.read(settingsProvider.notifier).completeOnboarding();
  }

  Future<void> _saveIncome(double amount, String source) async {
    final String title = source.isEmpty ? 'Maaş' : source;
    await ref.read(walletProvider.notifier).addTransaction(
          TransactionRecord(
            id: const Uuid().v4(),
            title: title,
            merchant: title,
            category: _incomeCategoryFor(source),
            amount: amount,
            date: DateTime.now(),
            type: TransactionType.income,
            source: TransactionSource.manual,
            paymentLabel: AppConstants.defaultIncomeLabel,
          ),
        );
    ref.read(tourProvider.notifier).next();
  }

  static String _incomeCategoryFor(String source) {
    if (source.isEmpty) return 'Maaş';
    final String canonical = source.toLowerCase();
    for (final String category in AppConstants.incomeCategories) {
      if (canonical.contains(category.toLowerCase())) return category;
    }
    return 'Maaş';
  }

  @override
  Widget build(BuildContext context) {
    final TourState tour = ref.watch(tourProvider);
    if (tour.running) _prepare(tour);

    final double width = MediaQuery.sizeOf(context).width;
    final Widget tabs = FolioTabSwitcher(currentIndex: _index, children: widget.children);

    final Widget shell = width >= 860
        ? _TabletShell(index: _index, onSelect: _goBranch, child: tabs)
        : Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 66 + 12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: tabs,
              ),
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _ClassicDock(
                currentIndex: _index,
                onTap: _goBranch,
                onAdd: () => _showAddMenu(context),
              ),
            ),
          );

    final TourStep? step = tour.step;
    if (step == null) return shell;

    return Stack(
      children: <Widget>[
        shell,
        TourOverlay(
          step: step,
          highlight: _highlight,
          isLast: tour.isLast,
          onNext: () {
            if (tour.isLast) {
              _finishTour();
            } else {
              ref.read(tourProvider.notifier).next();
            }
          },
          onSkip: _finishTour,
          onIncome: _saveIncome,
        ),
      ],
    );
  }
```

Keep the existing `_showAddMenu` method, changing its signature from `Future<void> _showAddMenu(BuildContext context) async` to the same thing on the state class — its body is unchanged.

- [ ] **Step 5: Anchor the dock and the rail**

In `_ClassicDock.build`, wrap each of the five controls:

```dart
      child: Row(
        children: <Widget>[
          Expanded(
            child: TourAnchor(
              target: TourTarget.homeTab,
              child: _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Ana', selected: currentIndex == 0, onTap: () => onTap(0)),
            ),
          ),
          Expanded(
            child: TourAnchor(
              target: TourTarget.transactionsTab,
              child: _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'İşlemler', selected: currentIndex == 1, onTap: () => onTap(1)),
            ),
          ),
          SizedBox(
            width: 54,
            child: Center(
              child: TourAnchor(target: TourTarget.addButton, child: _AddButton(onTap: onAdd)),
            ),
          ),
          Expanded(
            child: TourAnchor(
              target: TourTarget.analyticsTab,
              child: _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analiz', selected: currentIndex == 2, onTap: () => onTap(2)),
            ),
          ),
          Expanded(
            child: TourAnchor(
              target: TourTarget.profileTab,
              child: _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil', selected: currentIndex == 3, onTap: () => onTap(3)),
            ),
          ),
        ],
      ),
```

In `_TabletShell.build`, wrap the four rail icons the same way — `homeTab`, `transactionsTab`, `analyticsTab`, `profileTab`. The rail has no add button, so `addButton` goes unregistered there and its stop renders without a cut-out, which the overlay already handles.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/tour_shell_test.dart`
Expected: PASS, 8 tests

- [ ] **Step 7: Run the whole suite and analyze**

Run: `flutter test && flutter analyze`
Expected: all tests pass; no errors or warnings

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/shell/app_shell.dart test/tour_shell_test.dart test/support/fakes.dart
git commit -m "Let the shell drive the tour through its own tabs"
```

---

### Task 6: Delete the slide screen and rewire the entry point

**Files:**
- Delete: `lib/presentation/onboarding/onboarding_screen.dart`
- Delete: `test/onboarding_income_test.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: the tour from Task 5.
- Produces: `GoRouter buildAppRouter()` — no parameters. `FolioApp` no longer takes `onboardingSeen`.

The income-form behaviour that `test/onboarding_income_test.dart` covered now lives in `test/income_entry_card_test.dart` (Task 3) and `test/tour_shell_test.dart` (Task 5), so deleting it loses no coverage.

- [ ] **Step 1: Delete the screen and its test**

```bash
git rm lib/presentation/onboarding/onboarding_screen.dart test/onboarding_income_test.dart
```

- [ ] **Step 2: Drop the route and the parameter**

In `lib/core/router/app_router.dart`, remove the `OnboardingScreen` import, change the signature to `GoRouter buildAppRouter() {`, set `initialLocation: '/'`, and delete the `/onboarding` `GoRoute`.

In `lib/app.dart`:

```dart
class FolioApp extends ConsumerStatefulWidget {
  const FolioApp({super.key});

  @override
  ConsumerState<FolioApp> createState() => _FolioAppState();
}

class _FolioAppState extends ConsumerState<FolioApp> {
  late final GoRouter _router = buildAppRouter();
```

In `lib/main.dart`, delete the `onboardingSeen` local and pass `const FolioApp()`. Leave the `allowList` containing `'onboarding_seen'` — `SettingsController` still reads and writes that key.

- [ ] **Step 3: Run the whole suite and analyze**

Run: `flutter test && flutter analyze`
Expected: all tests pass; no errors or warnings. Any failure here is a missed reference to `OnboardingScreen` or to `buildAppRouter(onboardingSeen: ...)`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Retire the slide screen now that the tour runs inside the app"
```

---

### Task 7: Replay from Profile

**Files:**
- Modify: `lib/presentation/profile/profile_screen.dart`
- Test: `test/profile_tour_replay_test.dart`

**Interfaces:**
- Consumes: `tourProvider` (Task 1).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing test**

`test/profile_tour_replay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_wallet/core/theme/app_theme.dart';
import 'package:folio_wallet/presentation/profile/profile_screen.dart';
import 'package:folio_wallet/state/settings_controller.dart';
import 'package:folio_wallet/state/tour_controller.dart';
import 'package:folio_wallet/state/wallet_controller.dart';
import 'package:go_router/go_router.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Profile can start the tour again', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late WidgetRef captured;
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext c, GoRouterState s) => Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              captured = ref;
              return const ProfileScreen();
            },
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith(FakeWallet.new),
          settingsProvider.overrideWith(() => FakeSettings(hasSeenOnboarding: true)),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured.read(tourProvider).running, isFalse);

    await tester.scrollUntilVisible(find.text('Turu tekrar izle'), 200);
    await tester.tap(find.text('Turu tekrar izle'));
    await tester.pump();

    expect(captured.read(tourProvider).running, isTrue);
    expect(captured.read(tourProvider).index, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/profile_tour_replay_test.dart`
Expected: FAIL — no widget with text `Turu tekrar izle`

- [ ] **Step 3: Add the row**

In `lib/presentation/profile/profile_screen.dart`, add the import:

```dart
import '../../state/tour_controller.dart';
```

Then add a fourth row to the first `PremiumSurface`'s `Column`, after the `Aylık rapor` row and its `Divider`:

```dart
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                _SettingsRow(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Turu tekrar izle',
                  subtitle: 'Sekmeleri ve ne işe yaradıklarını baştan gez',
                  onTap: () {
                    ref.read(tourProvider.notifier).start();
                    context.go('/');
                  },
                ),
```

`ProfileScreen` is already a `ConsumerWidget`, so `ref` is in scope. `context.go('/')` returns to the first tab, where `AppShell` is mounted and can draw the overlay.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/profile_tour_replay_test.dart`
Expected: PASS, 1 test

- [ ] **Step 5: Run the whole suite and analyze**

Run: `flutter test && flutter analyze`
Expected: all tests pass; no errors or warnings

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/profile/profile_screen.dart test/profile_tour_replay_test.dart
git commit -m "Offer the tour again from Profile"
```

---

### Task 8: See it running

**Files:** none changed.

This task exists because every defect in this feature so far — the snackbar covering the skip button, the blank neighbouring page — was found by looking at the app, not by a passing test.

- [ ] **Step 1: Build and install on a running emulator**

```bash
flutter build apk --release --target-platform android-x64
adb uninstall com.folio.wallet
adb install build/app/outputs/flutter-apk/app-release.apk
```

`uninstall` first is required: split APKs carry versionCode `4001` and a single-platform build carries `1`, and Android refuses the downgrade — `adb install -r` fails silently in a way that looks like the code did not change.

- [ ] **Step 2: Start it clean and walk the tour**

```bash
adb shell pm clear com.folio.wallet
adb shell am start -n com.folio.wallet/.MainActivity
```

Use `am start`, not `monkey` — `monkey -c LAUNCHER 1` injects a random input event along with the launch, which advances the tour behind your back.

- [ ] **Step 3: Check each of these on the device, with a screenshot**

Capture with `adb exec-out screencap -p > shot.png` and look at each one:

1. The tour opens on the income card, over the dashboard rather than instead of it.
2. Entering an amount and saving moves to the Ana stop, and the dashboard behind now shows that figure.
3. Each stop's highlight sits on the right dock item, with the ring visible.
4. The bubble never covers the control it is pointing at.
5. The bubble's buttons are not under the gesture bar at the bottom of the screen.
6. `Geç` on any stop closes the tour and leaves the app usable.
7. Profile → `Turu tekrar izle` starts it again.

- [ ] **Step 4: Report what the device showed**

Report anything that looks wrong here rather than filing it as done. A finding at this step is a return to the failing-test cycle, not a note for later.

---

## Self-review

**Spec coverage**

| Spec requirement | Task |
|---|---|
| Slide screen replaced entirely | 6 |
| Tour drives tabs; user presses İleri | 5 |
| Income first | 1 (step order), 5 (saving) |
| `TourStep` / `TourTarget` / registry / controller / overlay | 1, 2, 4 |
| Stack in AppShell, not an Overlay entry | 5 |
| Six stops as listed, step 5 naming the period control | 1 |
| Wait for `FolioMotion.tab` before measuring | 5 |
| Unregistered target renders a bubble, does not throw | 2 (returns null), 4 (renders), 5 (rail has no add button) |
| Router loses `onboardingSeen`, always starts at `/` | 6 |
| Income form extracted, inline refusal kept | 3 |
| Profile replay | 7 |
| 44pt controls | 4 |
| Reduced motion | 4 |
| Scrim blocks taps underneath | 4 |
| Ring, not brightness alone | 4 |
| Test list from the spec | 1, 2, 3, 4, 5, 7 |

**Type consistency**

`TourTarget`, `TourStep`, `TourFormStep`, `TourSpotlightStep`, `kTourSteps`, `TourState`, `tourProvider`, `TourController.start/next/finish`, `TourTargetRegistry.register/unregister/rectOf`, `tourTargetRegistryProvider`, `TourAnchor`, `IncomeEntryCard.onSubmit/onSkip`, `TourOverlay.step/highlight/isLast/onNext/onSkip/onIncome` are each defined once and used with the same names and types throughout.

**Placeholders**

None. `FakeSettings` gains a constructor parameter in Task 5 Step 2 with the full replacement class given, and every code step carries the code it needs.
