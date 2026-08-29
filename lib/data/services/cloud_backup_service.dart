import 'dart:io';

import 'google_drive_backup_service.dart';
import 'icloud_backup_service.dart';
import 'wallet_backup_codec.dart';

class CloudAccount {
  const CloudAccount({required this.label, required this.provider});

  final String label;
  final String provider;
}

class CloudBackupException implements Exception {
  const CloudBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Writes the wallet to the user's own iCloud or Drive. Folio has no backend.
abstract class CloudBackupService {
  Future<CloudAccount?> currentAccount();

  Future<CloudAccount> connect();

  Future<void> disconnect();

  Future<DateTime?> lastRemoteBackupAt();

  Future<void> upload(WalletBackup backup);

  Future<WalletBackup?> download();

  static CloudBackupService create() {
    if (Platform.isIOS) return ICloudBackupService();
    if (Platform.isAndroid) return GoogleDriveBackupService();
    return const _UnsupportedCloudBackup();
  }
}

class _UnsupportedCloudBackup implements CloudBackupService {
  const _UnsupportedCloudBackup();

  @override
  Future<CloudAccount?> currentAccount() async => null;

  @override
  Future<CloudAccount> connect() async {
    throw const CloudBackupException('Bulut yedek yalnızca iPhone ve Android’de çalışır.');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<DateTime?> lastRemoteBackupAt() async => null;

  @override
  Future<void> upload(WalletBackup backup) async {
    throw const CloudBackupException('Bulut yedek yalnızca iPhone ve Android’de çalışır.');
  }

  @override
  Future<WalletBackup?> download() async => null;
}
