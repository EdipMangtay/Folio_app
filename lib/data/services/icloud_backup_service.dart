import 'package:flutter/services.dart';

import 'cloud_backup_service.dart';
import 'wallet_backup_codec.dart';

/// iCloud Drive container owned by the Apple ID signed into the phone.
class ICloudBackupService implements CloudBackupService {
  static const MethodChannel _channel = MethodChannel('folio.wallet/icloud');

  @override
  Future<CloudAccount?> currentAccount() async {
    try {
      final bool available = await _channel.invokeMethod<bool>('available') ?? false;
      if (!available) return null;
      return const CloudAccount(label: 'iCloud', provider: 'icloud');
    } on PlatformException catch (error) {
      throw CloudBackupException(_message(error));
    }
  }

  @override
  Future<CloudAccount> connect() async {
    final CloudAccount? account = await currentAccount();
    if (account == null) {
      throw const CloudBackupException(
        'iCloud kapalı. iPhone Ayarları > [adın] içinden iCloud’a giriş yap, sonra tekrar dene.',
      );
    }
    return account;
  }

  @override
  Future<void> disconnect() async {
    // iCloud identity is the device Apple ID; Folio cannot sign the user out.
  }

  @override
  Future<DateTime?> lastRemoteBackupAt() async {
    try {
      final String? raw = await _channel.invokeMethod<String>('modifiedAt');
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } on PlatformException catch (error) {
      throw CloudBackupException(_message(error));
    }
  }

  @override
  Future<void> upload(WalletBackup backup) async {
    try {
      await _channel.invokeMethod<void>('upload', WalletBackupCodec.encode(backup));
    } on PlatformException catch (error) {
      throw CloudBackupException(_message(error));
    }
  }

  @override
  Future<WalletBackup?> download() async {
    try {
      final String? raw = await _channel.invokeMethod<String>('download');
      if (raw == null || raw.isEmpty) return null;
      return WalletBackupCodec.decode(raw);
    } on PlatformException catch (error) {
      throw CloudBackupException(_message(error));
    } on FormatException catch (error) {
      throw CloudBackupException(error.message);
    }
  }

  String _message(PlatformException error) {
    final String? details = error.message;
    if (details != null && details.isNotEmpty) return details;
    return 'iCloud yedeği tamamlanamadı.';
  }
}
