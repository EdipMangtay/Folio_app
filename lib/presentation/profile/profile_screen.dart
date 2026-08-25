import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/services/wallet_exporter.dart';
import '../../domain/models/wallet_snapshot.dart';
import '../../state/settings_controller.dart';
import '../../state/tour_controller.dart';
import '../../state/wallet_controller.dart';
import '../widgets/folio_background.dart';
import '../widgets/folio_wordmark.dart';
import '../widgets/premium_surface.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsState settings = ref.watch(settingsProvider);
    final int transactionCount =
        ref.watch(walletProvider).value?.transactions.length ?? 0;
    return FolioBackground(
      accentAlignment: const Alignment(-0.95, -0.92),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 28),
        children: <Widget>[
          const Align(alignment: Alignment.centerLeft, child: FolioWordmark()),
          const SizedBox(height: 26),
          _ProfileHeroCard(
            settings: settings,
            onEdit: () => _editName(context, ref, settings.userName),
          ),
          const SizedBox(height: 34),
          const _SectionLabel('GÖRÜNÜM'),
          const SizedBox(height: 12),
          PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Uygulama görünümü', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Açık, koyu veya sistem temasını sakin bir görünümle seç.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                _ThemeSelector(
                  value: settings.themeMode,
                  onChanged: (ThemeMode mode) => ref.read(settingsProvider.notifier).setThemeMode(mode),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const _SectionLabel('FİNANS'),
          const SizedBox(height: 12),
          PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Column(
              children: <Widget>[
                _SettingsRow(
                  icon: Icons.donut_large_rounded,
                  title: 'Bütçeler',
                  subtitle: 'Kategori sınırlarını ve hedeflerini düzenle',
                  onTap: () => context.push('/budgets'),
                ),
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                _SettingsRow(
                  icon: Icons.repeat_rounded,
                  title: 'Abonelikler',
                  subtitle: 'Tekrarlayan giderlerini aylık görünümde incele',
                  onTap: () => context.push('/subscriptions'),
                ),
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                _SettingsRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Aylık rapor',
                  subtitle: 'Ayın finansal hikayesini tam ekran aç',
                  onTap: () => context.push('/monthly-report'),
                ),
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
              ],
            ),
          ),
          const SizedBox(height: 30),
          const _SectionLabel('VERİ VE GİZLİLİK'),
          const SizedBox(height: 12),
          PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: <Widget>[
                _PrivacyLockRow(
                  enabled: settings.privacyLockEnabled,
                  onChanged: (bool enabled) => _setPrivacyLock(context, ref, enabled),
                ),
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                const _InfoRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Cihazında saklanır',
                  subtitle: 'İşlemlerin telefonundaki uygulama klasöründe tutulur. '
                      'Hiçbir sunucuya gönderilmez, hesap açman gerekmez.',
                ),
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                const _InfoRow(
                  icon: Icons.credit_card_off_outlined,
                  title: 'Sınırlı kart bilgisi',
                  subtitle: 'Tam kart numarası tutulmaz; gerekirse yalnızca son dört hane gösterilir.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const _SectionLabel('VERİLERİM'),
          const SizedBox(height: 12),
          PremiumSurface(
            elevated: true,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Column(
              children: <Widget>[
                _SettingsRow(
                  icon: Icons.ios_share_rounded,
                  title: 'Verileri dışa aktar',
                  subtitle: transactionCount == 0
                      ? 'Dışa aktarılacak işlem yok.'
                      : '$transactionCount işlemi CSV olarak kaydet; Excel’de açılır, '
                          'Folio’ya geri aktarılabilir.',
                  onTap: () => _exportData(context, ref),
                ),
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                _SettingsRow(
                  icon: Icons.science_outlined,
                  title: 'Örnek veriyle dene',
                  subtitle: 'Kayıtlı işlemlerin silinir, yerine örnek bir cüzdan yüklenir.',
                  onTap: () => _loadDemoData(context, ref),
                ),
                Divider(height: 1, thickness: 0.7, color: Theme.of(context).dividerColor.withValues(alpha: 0.55)),
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Tüm verileri sil',
                  subtitle: transactionCount == 0
                      ? 'Kayıtlı işlem yok.'
                      : '$transactionCount işlem cihazından kalıcı olarak silinir.',
                  destructive: true,
                  onTap: () => _clearAllData(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Folio · Kişisel finans görünümü',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final TextEditingController controller = TextEditingController(text: current);
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Adın'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ad'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Kaydet')),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await ref.read(settingsProvider.notifier).setUserName(value);
  }

  Future<void> _setPrivacyLock(BuildContext context, WidgetRef ref, bool enabled) async {
    if (!enabled) {
      await ref.read(settingsProvider.notifier).setPrivacyLockEnabled(false);
      return;
    }
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool supported = await auth.isDeviceSupported();
      if (!supported) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu cihazda ekran kilidiyle doğrulama kullanılamıyor.')),
          );
        }
        return;
      }
      await ref.read(settingsProvider.notifier).setPrivacyLockEnabled(true);
    } on LocalAuthException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cihaz güvenliği kontrol edilemedi.')),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final WalletSnapshot? wallet = ref.read(walletProvider).value;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (wallet == null || wallet.transactions.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Dışa aktarılacak işlem yok.')));
      return;
    }

    try {
      final Uri? saved = await FilePicker.saveFile(
        fileName: WalletExporter.fileName(),
        bytes: WalletExporter.toCsvBytes(wallet.transactions),
        mimeType: 'text/csv',
        dialogTitle: 'Folio verilerini kaydet',
      );
      if (saved == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${wallet.transactions.length} işlem dışa aktarıldı.')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Dosya kaydedilemedi. Farklı bir konum deneyebilirsin.')),
      );
    }
  }

  Future<void> _loadDemoData(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Örnek veri yüklensin mi?',
      body: 'Şu anda kayıtlı olan tüm işlemler silinir ve yerlerine örnek bir cüzdan gelir. '
          'Bu işlem geri alınamaz.',
      action: 'Örnek veriyi yükle',
    );
    if (!confirmed) return;
    await ref.read(walletProvider.notifier).loadDemoData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Örnek cüzdan yüklendi.')),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final WalletSnapshot? wallet = ref.read(walletProvider).value;
    if (wallet == null || wallet.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silinecek işlem yok.')),
      );
      return;
    }
    final bool confirmed = await _confirm(
      context,
      title: 'Tüm veriler silinsin mi?',
      body: '${wallet.transactions.length} işlem cihazından kalıcı olarak silinir. '
          'Bütçe limitleri varsayılana döner. Bu işlem geri alınamaz.',
      action: 'Sil',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(walletProvider.notifier).clearAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm işlemler silindi.')),
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.coral)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.labelMedium);
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.settings, required this.onEdit});

  final SettingsState settings;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initial = settings.userName.isEmpty ? 'F' : settings.userName.substring(0, 1).toUpperCase();

    return PremiumSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.scaffoldBackgroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      settings.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Kişisel finans görünümü', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const <Widget>[
                        _HeroPill(icon: Icons.shield_outlined, label: 'Yerel veri'),
                        _HeroPill(icon: Icons.dark_mode_outlined, label: 'Sade görünüm'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 19), tooltip: 'Adı düzenle'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.soft(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.muted(theme.brightness)),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption(this.mode, this.label, this.icon);

  final ThemeMode mode;
  final String label;
  final IconData icon;
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_ThemeOption> options = <_ThemeOption>[
      const _ThemeOption(ThemeMode.system, 'Sistem', Icons.brightness_auto_outlined),
      const _ThemeOption(ThemeMode.light, 'Açık', Icons.light_mode_outlined),
      const _ThemeOption(ThemeMode.dark, 'Koyu', Icons.dark_mode_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.elevated(theme.brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.78), width: 0.7),
      ),
      child: Row(
        children: options.map((_ThemeOption option) {
          final bool selected = value == option.mode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(option.mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.onSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      option.icon,
                      size: 16,
                      color: selected ? theme.scaffoldBackgroundColor : AppColors.muted(theme.brightness),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected ? theme.scaffoldBackgroundColor : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = destructive ? AppColors.coral : theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive ? AppColors.coral.withValues(alpha: 0.10) : AppColors.soft(theme.brightness),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: destructive ? AppColors.coral : AppColors.muted(theme.brightness)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.tertiary(theme.brightness)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyLockRow extends StatelessWidget {
  const _PrivacyLockRow({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.soft(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.muted(Theme.of(context).brightness)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Cihaz kilidi', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'Face ID, parmak izi veya cihaz parolasıyla koru.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.soft(theme.brightness),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.muted(theme.brightness)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
