import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import 'automatic_backup_service.dart';

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>(
  (ref) => GoogleDriveBackupService(
    ref.watch(automaticBackupServiceProvider),
    ref.watch(secureStorageProvider),
  ),
);

/// Thrown when a Drive operation needs a connected account and there isn't
/// one - distinguished from other failures so UI can prompt to connect
/// rather than showing a generic error.
class GoogleDriveNotConnectedException implements Exception {
  const GoogleDriveNotConnectedException();
}

/// One backup file already uploaded to the hidden app-data folder.
class GoogleDriveBackupSummary {
  const GoogleDriveBackupSummary({
    required this.fileId,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String fileId;
  final String name;
  final DateTime? modifiedAt;
  final int? sizeBytes;
}

/// Mirrors the local encrypted backups AutomaticBackupService already makes
/// into the merchant's own Google Drive (hidden appdata folder - see
/// [[project-drive-backup-and-ios-browser-design]] for the design this
/// implements). NexaPOS never holds the merchant's Google credentials or
/// backup encryption key on any server it operates - the refresh token
/// lives only on this device, and the local backup key is escrowed to
/// Drive only wrapped under a recovery passphrase only the merchant knows.
class GoogleDriveBackupService {
  GoogleDriveBackupService(this._localBackup, this._storage);

  final AutomaticBackupService _localBackup;
  final FlutterSecureStorage _storage;

  static const _scope = drive.DriveApi.driveAppdataScope;
  static const _keyEnvelopeFileName = 'nexapos-backup-key-envelope.json';
  static const _backupNamePrefix = 'NexaPOS-drive-backup-';
  static const _backupRetention = 7;

  // Desktop OAuth client ID - Google treats this as a public identifier,
  // safe to embed (unlike the secret below). See
  // release-tools/google-drive-oauth-clients.json for where both values
  // are tracked outside this (public) repo.
  static const _windowsClientIdentifier =
      '164205212571-umin19nof5d9vm6hc0bsdfi5q8269ioi.apps.googleusercontent.com';

  // The secret is injected at build time (see
  // release-tools/build-windows-*.cmd) rather than committed as a literal
  // - Google's own guidance is this isn't meaningfully confidential for an
  // installed app (PKCE is the real protection), but this repo is public
  // and the project's own rule is no credentials in commits regardless.
  static const _windowsClientSecret = String.fromEnvironment(
    'NEXAPOS_GOOGLE_WINDOWS_CLIENT_SECRET',
  );

  static final gauth.ClientId _windowsClientId = gauth.ClientId(
    _windowsClientIdentifier,
    _windowsClientSecret.isEmpty ? null : _windowsClientSecret,
  );

  static const _windowsRefreshTokenKey = 'nexapos.googleDrive.windowsRefreshToken';
  static const _windowsEmailKey = 'nexapos.googleDrive.windowsEmail';

  bool get _isWindows => Platform.isWindows;

  static bool _androidSignInInitialized = false;
  Future<void> _ensureAndroidSignInInitialized() async {
    if (_androidSignInInitialized) return;
    await GoogleSignIn.instance.initialize();
    _androidSignInInitialized = true;
  }

  /// The connected account's email, or null if Drive isn't connected.
  Future<String?> connectedEmail() async {
    if (_isWindows) {
      return _storage.read(key: _windowsEmailKey);
    }
    await _ensureAndroidSignInInitialized();
    final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    return account?.email;
  }

  /// Runs the sign-in flow, requests the appdata scope, and uploads a
  /// passphrase-wrapped copy of the local backup key so a future device can
  /// recover it. Must be called from a user-initiated action (a button
  /// press), not automatically - both platforms' consent flows require it.
  Future<String> connect({required String recoveryPassphrase}) async {
    final email = _isWindows ? await _connectWindows() : await _connectAndroid();
    await _uploadKeyEnvelope(recoveryPassphrase);
    return email;
  }

  Future<String> _connectAndroid() async {
    await _ensureAndroidSignInInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    await account.authorizationClient.authorizeScopes([_scope]);
    return account.email;
  }

  Future<String> _connectWindows() async {
    if (_windowsClientSecret.isEmpty) {
      throw StateError(
        'This build was not compiled with the Google Drive Windows client '
        'secret. Rebuild with --dart-define=NEXAPOS_GOOGLE_WINDOWS_CLIENT_SECRET=... '
        '(see release-tools/build-windows-*.cmd).',
      );
    }
    final verifier = _pkceVerifier();
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}/';
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _windowsClientId.identifier,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': _scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
    });

    final codeCompleter = Completer<String>();
    final subscription = server.listen((request) async {
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<html><body style="font-family:sans-serif;padding:40px;text-align:center">'
        '<h2>NexaPOS</h2><p>You can close this window and return to NexaPOS.</p>'
        '</body></html>',
      );
      await request.response.close();
      if (!codeCompleter.isCompleted) {
        if (code != null) {
          codeCompleter.complete(code);
        } else {
          codeCompleter.completeError(
            StateError('Google sign-in was cancelled or failed${error != null ? ': $error' : '.'}'),
          );
        }
      }
    });

    try {
      final opened = await launchUrl(authUri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Could not open a browser for Google sign-in.');
      }
      final code = await codeCompleter.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw StateError('Google sign-in timed out. Please try again.'),
      );
      final credentials = await gauth.obtainAccessCredentialsViaCodeExchange(
        http.Client(),
        _windowsClientId,
        code,
        redirectUrl: redirectUri,
        codeVerifier: verifier,
      );
      final refreshToken = credentials.refreshToken;
      if (refreshToken == null) {
        throw StateError(
          'Google did not return a long-lived token. If you connected '
          'before, remove NexaPOS at myaccount.google.com/permissions and try again.',
        );
      }
      final email = await _emailForCredentials(credentials);
      await _storage.write(key: _windowsRefreshTokenKey, value: refreshToken);
      await _storage.write(key: _windowsEmailKey, value: email);
      return email;
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Future<String> _emailForCredentials(gauth.AccessCredentials credentials) async {
    final client = gauth.authenticatedClient(http.Client(), credentials);
    try {
      final about = await drive.DriveApi(client).about.get($fields: 'user');
      return about.user?.emailAddress ?? 'your Google account';
    } finally {
      client.close();
    }
  }

  /// Revokes NexaPOS's Drive access and clears everything stored on this
  /// device. Files already uploaded stay in the merchant's own Drive -
  /// NexaPOS has no other way to reach them once disconnected.
  Future<void> disconnect() async {
    if (_isWindows) {
      final refreshToken = await _storage.read(key: _windowsRefreshTokenKey);
      if (refreshToken != null) {
        try {
          await http.post(
            Uri.https('oauth2.googleapis.com', '/revoke'),
            body: {'token': refreshToken},
          );
        } catch (_) {
          // Best effort - clearing local storage below still removes
          // NexaPOS's ability to use the token even if revoke fails.
        }
      }
      await _storage.delete(key: _windowsRefreshTokenKey);
      await _storage.delete(key: _windowsEmailKey);
      return;
    }
    await _ensureAndroidSignInInitialized();
    await GoogleSignIn.instance.disconnect();
  }

  /// Uploads the most recent local backup (see
  /// AutomaticBackupService.latestBackupFile) to the hidden appdata folder,
  /// and prunes older Drive copies down to the same retention window the
  /// local rotation already uses. A no-op if Drive isn't connected or there
  /// is no local backup yet - never blocks the local backup path.
  Future<void> uploadLatestBackupIfConnected() async {
    if (await connectedEmail() == null) return;
    final file = await _localBackup.latestBackupFile();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _withDriveApi((api) async {
      await api.files.create(
        drive.File(name: '$_backupNamePrefix${DateTime.now().toUtc().millisecondsSinceEpoch}.nexabackup', parents: const ['appDataFolder']),
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
      await _pruneOldBackups(api);
    });
  }

  Future<void> _pruneOldBackups(drive.DriveApi api) async {
    final list = await api.files.list(
      q: "name contains '$_backupNamePrefix' and trashed = false",
      spaces: 'appDataFolder',
      orderBy: 'name desc',
      $fields: 'files(id,name)',
    );
    final files = list.files ?? const [];
    for (final file in files.skip(_backupRetention)) {
      final id = file.id;
      if (id != null) await api.files.delete(id);
    }
  }

  Future<List<GoogleDriveBackupSummary>> listBackups() {
    return _withDriveApi((api) async {
      final list = await api.files.list(
        q: "name contains '$_backupNamePrefix' and trashed = false",
        spaces: 'appDataFolder',
        orderBy: 'name desc',
        $fields: 'files(id,name,modifiedTime,size)',
      );
      return (list.files ?? const [])
          .map(
            (f) => GoogleDriveBackupSummary(
              fileId: f.id ?? '',
              name: f.name ?? '',
              modifiedAt: f.modifiedTime,
              sizeBytes: f.size == null ? null : int.tryParse(f.size!),
            ),
          )
          .where((s) => s.fileId.isNotEmpty)
          .toList();
    });
  }

  Future<Uint8List> downloadBackup(String fileId) {
    return _withDriveApi((api) async {
      final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final chunks = <int>[];
      await for (final chunk in media.stream) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    });
  }

  /// Downloads the key envelope and unwraps it with [recoveryPassphrase],
  /// returning the raw local backup key bytes to decrypt a downloaded
  /// backup with ArchiveEncryption.decode. Throws if the passphrase is
  /// wrong or no envelope was ever uploaded (e.g. Drive was connected on a
  /// version before this feature existed).
  Future<Uint8List> recoverBackupKey({required String recoveryPassphrase}) {
    return _withDriveApi((api) async {
      final list = await api.files.list(
        q: "name = '$_keyEnvelopeFileName' and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id)',
      );
      final files = list.files ?? const [];
      final id = files.isEmpty ? null : files.first.id;
      if (id == null) {
        throw StateError('No recoverable key was found for this Google account.');
      }
      final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final chunks = <int>[];
      await for (final chunk in media.stream) {
        chunks.addAll(chunk);
      }
      return BackupKeyEnvelope.unwrap(Uint8List.fromList(chunks), recoveryPassphrase);
    });
  }

  Future<void> _uploadKeyEnvelope(String recoveryPassphrase) async {
    final rawKey = base64Url.decode(await _localBackup.backupKey());
    final envelope = await BackupKeyEnvelope.wrap(rawKey, recoveryPassphrase);
    await _withDriveApi((api) async {
      final list = await api.files.list(
        q: "name = '$_keyEnvelopeFileName' and trashed = false",
        spaces: 'appDataFolder',
        $fields: 'files(id)',
      );
      final existingFiles = list.files ?? const [];
      final existingId = existingFiles.isEmpty ? null : existingFiles.first.id;
      final media = drive.Media(Stream.value(envelope), envelope.length);
      if (existingId != null) {
        await api.files.update(drive.File(), existingId, uploadMedia: media);
      } else {
        await api.files.create(
          drive.File(name: _keyEnvelopeFileName, parents: const ['appDataFolder']),
          uploadMedia: media,
        );
      }
    });
  }

  String _pkceVerifier() {
    final bytes = List<int>.generate(64, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<T> _withDriveApi<T>(Future<T> Function(drive.DriveApi api) action) async {
    late final http.Client client;
    if (_isWindows) {
      final refreshToken = await _storage.read(key: _windowsRefreshTokenKey);
      if (refreshToken == null) throw const GoogleDriveNotConnectedException();
      client = await gauth.clientViaRefreshToken(_windowsClientId, refreshToken, [_scope]);
    } else {
      await _ensureAndroidSignInInitialized();
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account == null) throw const GoogleDriveNotConnectedException();
      final authorization =
          await account.authorizationClient.authorizationForScopes([_scope]) ??
          await account.authorizationClient.authorizeScopes([_scope]);
      client = gauth.authenticatedClient(
        http.Client(),
        gauth.AccessCredentials(
          gauth.AccessToken('Bearer', authorization.accessToken, DateTime.now().toUtc().add(const Duration(minutes: 30))),
          null,
          [_scope],
        ),
      );
    }
    try {
      return await action(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }
}

/// Wraps/unwraps the local backup key under a merchant-chosen recovery
/// passphrase, independent of Drive/OAuth so it's directly testable and
/// reusable if key escrow is ever needed outside of Drive. Deliberately
/// mirrors ArchiveEncryption's exact KDF cost and cipher (see
/// data/import/shop_archive.dart) rather than inventing a second crypto
/// convention in the same codebase.
class BackupKeyEnvelope {
  static const _pbkdf2Iterations = 210000;

  static Future<Uint8List> wrap(List<int> rawKey, String passphrase) async {
    final cipher = AesGcm.with256bits();
    final salt = cipher.newNonce();
    final wrappingKey = await _deriveWrappingKey(passphrase, salt);
    final box = await cipher.encrypt(
      rawKey,
      secretKey: wrappingKey,
      aad: utf8.encode('nexapos.drive.key-envelope.v1'),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'nexapos.drive.key-envelope',
          'version': 1,
          'salt': base64Encode(salt),
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
          'data': base64Encode(box.cipherText),
        }),
      ),
    );
  }

  static Future<Uint8List> unwrap(Uint8List envelopeBytes, String passphrase) async {
    final envelope = jsonDecode(utf8.decode(envelopeBytes)) as Map<String, dynamic>;
    if (envelope['format'] != 'nexapos.drive.key-envelope' || envelope['version'] != 1) {
      throw const FormatException('This does not look like a NexaPOS Drive backup key.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final nonce = base64Decode(envelope['nonce'] as String);
    final mac = base64Decode(envelope['mac'] as String);
    final wrappingKey = await _deriveWrappingKey(passphrase, salt);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(envelope['data'] as String), nonce: nonce, mac: Mac(mac)),
        secretKey: wrappingKey,
        aad: utf8.encode('nexapos.drive.key-envelope.v1'),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw StateError('That recovery passphrase is incorrect.');
    }
  }

  static Future<SecretKey> _deriveWrappingKey(String passphrase, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha512(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
}
