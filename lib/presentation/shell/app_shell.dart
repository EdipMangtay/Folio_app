import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/motion/folio_motion.dart';
import '../../core/motion/folio_tab_switcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/models/transaction_record.dart';
import '../../domain/tour/tour_step.dart';
import '../../state/settings_controller.dart';
import '../../state/tour_controller.dart';
import '../../state/wallet_controller.dart';
import '../add/add_transaction_sheet.dart';
import '../tour/tour_anchor.dart';
import '../tour/tour_overlay.dart';
import '../widgets/folio_wordmark.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, required this.children, super.key});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Where the current stop's target sits, measured once its tab has settled.
  Rect? _highlight;
  int _measuredFor = -1;

  int get _index => widget.navigationShell.currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(settingsProvider).hasSeenOnboarding) {
        ref.read(tourProvider.notifier).start();
      }
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
    if (_measuredFor == tour.index) return;
    _measuredFor = tour.index;
    final TourStep? step = tour.step;

    // Deferred out of build: goBranch is a navigation, and a navigation
    // started while the frame is being built is dropped.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (step is! TourSpotlightStep) {
        setState(() => _highlight = null);
        return;
      }
      if (_index != step.tab) {
        _goBranch(step.tab);
        await Future<void>.delayed(FolioMotion.tab + const Duration(milliseconds: 32));
      }
      if (!mounted) return;
      final TourTargetRegistry registry = ref.read(tourTargetRegistryProvider);
      registry.ensureVisible(step.target);
      setState(() => _highlight = registry.rectOf(step.target));

      // Re-measure after scroll animation settles so highlight is 100% pixel-perfect.
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted || tour.index != _measuredFor) return;
      final Rect? settledRect = registry.rectOf(step.target);
      if (settledRect != null && settledRect != _highlight) {
        setState(() => _highlight = settledRect);
      }
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
    if (mounted) ref.read(tourProvider.notifier).next();
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
    final double dockClearance = 66 + 12 + MediaQuery.paddingOf(context).bottom;

    final Widget shell = width >= 860
        ? _TabletShell(index: _index, onSelect: _goBranch, child: tabs)
        : Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: dockClearance),
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
          position: tour.index + 1,
          total: kTourSteps.length,
          onNext: () {
            if (tour.isLast) {
              _finishTour();
            } else {
              ref.read(tourProvider.notifier).next();
            }
          },
          onPrevious: () => ref.read(tourProvider.notifier).previous(),
          onSkip: _finishTour,
          onIncome: _saveIncome,
        ),
      ],
    );
  }

  Future<void> _showAddMenu(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.26),
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.elevated(theme.brightness),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
              border: Border.all(color: theme.dividerColor, width: 0.8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary(theme.brightness).withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Text('Yeni kayıt', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 5),
                Text('İşlemi sana en rahat gelen yöntemle ekle.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 18),
                _AddMenuItem(
                  icon: Icons.document_scanner_outlined,
                  title: 'Fiş tara',
                  subtitle: 'Kamerayla otomatik doldur',
                  tone: AppColors.sage,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/receipt');
                  },
                ),
                _AddMenuItem(
                  icon: Icons.edit_rounded,
                  title: 'Harcama gir',
                  subtitle: 'Manuel olarak hızlıca ekle',
                  tone: AppColors.accent(theme.brightness),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await showAddTransactionSheet(context);
                  },
                ),
                _AddMenuItem(
                  icon: Icons.file_upload_outlined,
                  title: 'Ekstre aktar',
                  subtitle: 'CSV, XLSX veya PDF',
                  tone: AppColors.blueGray,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/statement');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClassicDock extends StatelessWidget {
  const _ClassicDock({required this.currentIndex, required this.onTap, required this.onAdd});

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.elevated(theme.brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor, width: 0.8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.45 : 0.055),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
    );
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Yeni kayıt ekle',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1,
          duration: FolioMotion.quick,
          curve: FolioMotion.enter,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent(theme.brightness),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.add_rounded, color: AppColors.canvas(theme.brightness), size: 24),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color active = AppColors.ink(theme.brightness);
    final Color inactive = AppColors.muted(theme.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: SizedBox.expand(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(selected ? activeIcon : icon, size: 20, color: selected ? active : inactive),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: FolioMotion.tab,
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: selected ? active : inactive,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMenuItem extends StatelessWidget {
  const _AddMenuItem({required this.icon, required this.title, required this.subtitle, required this.tone, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: tone),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.tertiary(theme.brightness)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletShell extends StatelessWidget {
  const _TabletShell({required this.index, required this.onSelect, required this.child});

  final int index;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: <Widget>[
          SafeArea(
            child: SizedBox(
              width: 106,
              child: Column(
                children: <Widget>[
                  const Padding(padding: EdgeInsets.only(top: 20, bottom: 30), child: FolioWordmark(compact: true)),
                  TourAnchor(
                    target: TourTarget.homeTab,
                    child: _RailIcon(icon: Icons.home_rounded, selected: index == 0, onTap: () => onSelect(0)),
                  ),
                  TourAnchor(
                    target: TourTarget.transactionsTab,
                    child: _RailIcon(icon: Icons.receipt_long_rounded, selected: index == 1, onTap: () => onSelect(1)),
                  ),
                  TourAnchor(
                    target: TourTarget.analyticsTab,
                    child: _RailIcon(icon: Icons.bar_chart_rounded, selected: index == 2, onTap: () => onSelect(2)),
                  ),
                  const Spacer(),
                  TourAnchor(
                    target: TourTarget.profileTab,
                    child: _RailIcon(icon: Icons.person_outline_rounded, selected: index == 3, onTap: () => onSelect(3)),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: theme.dividerColor),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTransactionSheet(context),
        backgroundColor: AppColors.accent(theme.brightness),
        foregroundColor: AppColors.canvas(theme.brightness),
        elevation: 1,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.icon, required this.selected, required this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          minimumSize: const Size(52, 52),
          backgroundColor: selected ? AppColors.accentSoft(theme.brightness) : Colors.transparent,
          foregroundColor: selected ? AppColors.ink(theme.brightness) : AppColors.muted(theme.brightness),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
