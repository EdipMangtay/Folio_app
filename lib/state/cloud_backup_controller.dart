import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/cloud_backup_service.dart';
import '../data/services/wallet_backup_codec.dart';
import 'settings_controller.dart';
import 'wallet_controller.dart';

class CloudBackupState {
  const CloudBackupState({
    this.account,
    this.lastBackupAt,
    this.busy = false,
  });

  final CloudAccount? account;
  final DateTime? lastBackupAt;
  final bool busy;

  bool get connected => account != null;

  CloudBackupState copyWith({
    CloudAccount? account,
    DateTime? lastBackupAt,
    bool? busy,
    bool clearAccount = false,
    bool clearBackup = false,
  }) {
    return CloudBackupState(
      account: clearAccount ? null : (account ?? this.account),
      lastBackupAt: clearBackup ? null : (lastBackupAt ?? this.lastBackupAt),
      busy: busy ?? this.busy,
    );
  }
}

final Provider<CloudBackupService> cloudBackupServiceProvider = Provider<CloudBackupService>(
  (Ref ref) => CloudBackupService.create(),
);

final NotifierProvider<CloudBackupController, CloudBackupState> cloudBackupProvider =
    NotifierProvider<CloudBackupController, CloudBackupState>(CloudBackupController.new);

class CloudBackupController extends Notifier<CloudBackupState> {
  static const String _lastBackupKey = 'cloud_last_backup_at';

  CloudBackupService get _cloud => ref.read(cloudBackupServiceProvider);

  @override
  CloudBackupState build() {
    Future<void>.microtask(_refresh);
    return CloudBackupState(lastBackupAt: _storedLastBackup());
  }

  DateTime? _storedLastBackup() {
    try {
      final String? stored = ref.read(preferencesProvider).getString(_lastBackupKey);
      return stored == null || stored.isEmpty ? null : DateTime.tryParse(stored);
    } on Object {
      return null;
    }
  }

  Future<void> _persistLastBackup(DateTime at) async {
    try {
      await ref.read(preferencesProvider).setString(_lastBackupKey, at.toIso8601String());
    } on Object {
      // Widget tests (and a missing prefs override) still keep the timestamp in memory.
    }
  }

  Future<void> _refresh() async {
    try {
      final CloudAccount? account = await _cloud.currentAccount();
      DateTime? remote;
      if (account != null) {
        remote = await _cloud.lastRemoteBackupAt();
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        account: account,
        lastBackupAt: remote ?? state.lastBackupAt,
        busy: false,
        clearAccount: account == null,
      );
    } on Object {
      if (!ref.mounted) return;
      state = state.copyWith(busy: false);
    }
  }

  Future<void> connect() async {
    state = state.copyWith(busy: true);
    try {
      final CloudAccount account = await _cloud.connect();
      final DateTime? remote = await _cloud.lastRemoteBackupAt();
      if (!ref.mounted) return;
      state = state.copyWith(account: account, lastBackupAt: remote, busy: false);
    } on CloudBackupException {
      rethrow;
    } on Object {
      throw const CloudBackupException('Hesaba bağlanılamadı.');
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> disconnect() async {
    await _cloud.disconnect();
    if (!ref.mounted) return;
    state = state.copyWith(clearAccount: true, busy: false);
  }

  Future<void> backup() async {
    final snapshot = ref.read(walletProvider).value;
    if (snapshot == null) {
      throw const CloudBackupException('Cüzdan henüz yüklenmedi.');
    }
    state = state.copyWith(busy: true);
    try {
      CloudAccount? account = state.account ?? await _cloud.currentAccount();
      account ??= await _cloud.connect();
      final DateTime now = DateTime.now().toUtc();
      await _cloud.upload(
        WalletBackup(
          exportedAt: now,
          userName: ref.read(settingsProvider).userName,
          snapshot: snapshot,
        ),
      );
      await _persistLastBackup(now);
      if (!ref.mounted) return;
      state = state.copyWith(account: account, lastBackupAt: now, busy: false);
    } on CloudBackupException {
      rethrow;
    } on Object {
      throw const CloudBackupException('Yedek tamamlanamadı.');
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> restore() async {
    state = state.copyWith(busy: true);
    try {
      CloudAccount? account = state.account ?? await _cloud.currentAccount();
      account ??= await _cloud.connect();
      final WalletBackup? backup = await _cloud.download();
      if (backup == null) {
        throw const CloudBackupException('Kayıtlı bir yedek yok.');
      }
      await ref.read(walletProvider.notifier).restoreFromBackup(backup.snapshot);
      if (backup.userName.trim().isNotEmpty) {
        await ref.read(settingsProvider.notifier).setUserName(backup.userName);
      }
      await _persistLastBackup(backup.exportedAt);
      if (!ref.mounted) return;
      state = state.copyWith(account: account, lastBackupAt: backup.exportedAt, busy: false);
    } on CloudBackupException {
      rethrow;
    } on Object {
      throw const CloudBackupException('Yedek geri yüklenemedi.');
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }
}
