import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'cloud_backup_service.dart';
import 'wallet_backup_codec.dart';

/// Hidden Drive appData folder on the Google account the user signs in with.
class GoogleDriveBackupService implements CloudBackupService {
  static const String _scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const String _files = 'https://www.googleapis.com/drive/v3/files';

  final GoogleSignIn _google = GoogleSignIn(scopes: <String>[_scope]);

  @override
  Future<CloudAccount?> currentAccount() async {
    final GoogleSignInAccount? user = _google.currentUser ?? await _google.signInSilently();
    if (user == null) return null;
    return CloudAccount(label: user.email, provider: 'google');
  }

  @override
  Future<CloudAccount> connect() async {
    try {
      final GoogleSignInAccount? user = await _google.signIn();
      if (user == null) {
        throw const CloudBackupException('Google girişi iptal edildi.');
      }
      return CloudAccount(label: user.email, provider: 'google');
    } on CloudBackupException {
      rethrow;
    } on Object {
      throw const CloudBackupException(
        'Google hesabına bağlanılamadı. Play hizmetlerini kontrol edip tekrar dene.',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    await _google.signOut();
  }

  @override
  Future<DateTime?> lastRemoteBackupAt() async {
    final _DriveFile? file = await _find();
    return file?.modifiedAt;
  }

  @override
  Future<void> upload(WalletBackup backup) async {
    final String json = WalletBackupCodec.encode(backup);
    final _DriveFile? existing = await _find();
    final List<int> bytes = utf8.encode(json);
    if (existing == null) {
      await _multipart(
        uri: Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
        metadata: <String, Object?>{
          'name': WalletBackupCodec.fileName,
          'parents': <String>['appDataFolder'],
        },
        bytes: bytes,
      );
      return;
    }
    await _multipart(
      uri: Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files/${existing.id}?uploadType=multipart',
      ),
      metadata: <String, Object?>{'name': WalletBackupCodec.fileName},
      bytes: bytes,
      patch: true,
    );
  }

  @override
  Future<WalletBackup?> download() async {
    final _DriveFile? file = await _find();
    if (file == null) return null;
    final http.Response response = await _client.get(
      Uri.parse('$_files/${file.id}?alt=media'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CloudBackupException('Drive yedeği indirilemedi.');
    }
    try {
      return WalletBackupCodec.decode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw CloudBackupException(error.message);
    }
  }

  Future<_DriveFile?> _find() async {
    final Uri uri = Uri.parse(_files).replace(
      queryParameters: <String, String>{
        'spaces': 'appDataFolder',
        'fields': 'files(id,modifiedTime)',
        'q': "name = '${WalletBackupCodec.fileName}' and trashed = false",
      },
    );
    final http.Response response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CloudBackupException('Drive yedeğine erişilemedi.');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['files'] is! List) return null;
    final List<dynamic> files = decoded['files'] as List<dynamic>;
    if (files.isEmpty || files.first is! Map) return null;
    final Map<dynamic, dynamic> first = files.first as Map<dynamic, dynamic>;
    final Object? id = first['id'];
    if (id is! String || id.isEmpty) return null;
    return _DriveFile(id: id, modifiedAt: DateTime.tryParse('${first['modifiedTime'] ?? ''}'));
  }

  Future<void> _multipart({
    required Uri uri,
    required Map<String, Object?> metadata,
    required List<int> bytes,
    bool patch = false,
  }) async {
    const String boundary = 'folio_wallet_backup';
    final List<int> body = <int>[
      ...utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n'),
      ...utf8.encode(jsonEncode(metadata)),
      ...utf8.encode('\r\n--$boundary\r\nContent-Type: application/json\r\n\r\n'),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--\r\n'),
    ];
    final http.Request request = http.Request(patch ? 'PATCH' : 'POST', uri)
      ..headers['Content-Type'] = 'multipart/related; boundary=$boundary'
      ..bodyBytes = body;
    final http.StreamedResponse streamed = await _client.send(request);
    final http.Response response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const CloudBackupException('Drive yedeği kaydedilemedi.');
    }
  }

  late final http.Client _client = _GoogleAuthClient(_headers);

  Future<Map<String, String>> _headers() async {
    GoogleSignInAccount? user = _google.currentUser ?? await _google.signInSilently();
    user ??= await _google.signIn();
    if (user == null) {
      throw const CloudBackupException('Google hesabı bağlı değil.');
    }
    return user.authHeaders;
  }
}

class _DriveFile {
  const _DriveFile({required this.id, required this.modifiedAt});
  final String id;
  final DateTime? modifiedAt;
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Future<Map<String, String>> Function() _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(await _headers());
    return _inner.send(request);
  }
}
