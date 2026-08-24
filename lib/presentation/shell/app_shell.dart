import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/folio_motion.dart';
import '../../core/motion/folio_tab_switcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../add/add_transaction_sheet.dart';
import '../widgets/folio_wordmark.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, required this.children, super.key});

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  int get _index => navigationShell.currentIndex;

  void _goBranch(int index) {
    if (index != _index) HapticFeedback.selectionClick();
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final Widget tabs = FolioTabSwitcher(currentIndex: _index, children: children);
    if (width >= 860) return _TabletShell(index: _index, onSelect: _goBranch, child: tabs);

    final double dockClearance = 66 + 12 + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
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
            color: Colors.black.withValues(alpha: dark ? 0.22 : 0.055),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Ana', selected: currentIndex == 0, onTap: () => onTap(0))),
          Expanded(child: _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'İşlemler', selected: currentIndex == 1, onTap: () => onTap(1))),
          SizedBox(width: 54, child: Center(child: _AddButton(onTap: onAdd))),
          Expanded(child: _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analiz', selected: currentIndex == 2, onTap: () => onTap(2))),
          Expanded(child: _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profil', selected: currentIndex == 3, onTap: () => onTap(3))),
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
            child: Icon(Icons.add_rounded, color: AppColors.elevated(theme.brightness), size: 24),
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
                  _RailIcon(icon: Icons.home_rounded, selected: index == 0, onTap: () => onSelect(0)),
                  _RailIcon(icon: Icons.receipt_long_rounded, selected: index == 1, onTap: () => onSelect(1)),
                  _RailIcon(icon: Icons.bar_chart_rounded, selected: index == 2, onTap: () => onSelect(2)),
                  const Spacer(),
                  _RailIcon(icon: Icons.person_outline_rounded, selected: index == 3, onTap: () => onSelect(3)),
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
        foregroundColor: AppColors.elevated(theme.brightness),
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
