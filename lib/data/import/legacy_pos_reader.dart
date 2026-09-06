import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'shop_archive.dart';

class LegacyPosReader {
  static Uri localUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        !['localhost', '127.0.0.1', '::1'].contains(uri.host) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Use a local POS URL on localhost or 127.0.0.1.',
      );
    }
    return uri;
  }

  Future<String> inspect(String url) async {
    final uri = localUri(url);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200)
        throw StateError(
          'POS returned HTTP ${response.statusCode}. Check the login URL.',
        );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 1024 * 1024)
          throw StateError('POS page exceeds the supported size.');
      }
      final html = utf8.decode(bytes, allowMalformed: true);
      if (!html.contains('NexaPOS'))
        throw StateError(
          'This POS needs a supported migration adapter or export.',
        );
      return 'NexaPOS browser edition detected. Connect its local database to preview migration.';
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> readDatabase({
    required String url,
    required String phpPath,
    required String database,
    required String username,
    required String password,
    int port = 3306,
  }) async {
    await inspect(url);
    if (!Platform.isWindows)
      throw UnsupportedError('Import an XAMPP database from the Windows app.');
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(database) ||
        port < 1 ||
        port > 65535) {
      throw const FormatException('Enter a valid database name and port.');
    }
    if (!File(phpPath).isAbsolute ||
        !phpPath.toLowerCase().endsWith('php.exe') ||
        !await File(phpPath).exists()) {
      throw const FormatException('Select the installed XAMPP php.exe.');
    }
    final process = await Process.start(phpPath, [
      '-r',
      _exportScript,
    ], runInShell: false);
    final timer = Timer(const Duration(minutes: 2), () => process.kill());
    final errors = process.stderr.drain<void>();
    final bytes = <int>[];
    try {
      process.stdin.write(
        jsonEncode({
          'database': database,
          'username': username,
          'password': password,
          'port': port,
        }),
      );
      await process.stdin.close();
      await for (final chunk in process.stdout) {
        bytes.addAll(chunk);
        if (bytes.length > maxArchiveBytes ~/ 2) {
          process.kill();
          throw StateError(
            'Legacy database exceeds the supported migration size.',
          );
        }
      }
      final exit = await process.exitCode;
      await errors;
      if (exit != 0)
        throw StateError(
          'Cannot read the source database. Check credentials, database name, and read permissions.',
        );
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      data['source'] =
          'legacy:${sha256.convert(utf8.encode('${localUri(url).origin}/$database'))}';
      return data;
    } finally {
      timer.cancel();
      process.kill();
    }
  }
}

// Credentials travel through stdin, never command arguments, files or logs.
// The source connection is read-only and all selected data shares one snapshot.
const _exportScript = r'''
try {
    $c = json_decode(stream_get_contents(STDIN), true, 32, JSON_THROW_ON_ERROR);
    if (!preg_match('/^[A-Za-z0-9_]+$/D', $c['database'])) { exit(2); }
    $pdo = new PDO('mysql:host=127.0.0.1;port='.(int)$c['port'].';dbname='.$c['database'].';charset=utf8mb4',
        $c['username'], $c['password'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $pdo->exec("SET time_zone = '+00:00'");
    $meta = $pdo->query('SELECT TABLE_NAME, ENGINE FROM information_schema.tables WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE="BASE TABLE"')->fetchAll(PDO::FETCH_ASSOC);
    $pdo->exec('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ');
    $pdo->exec('START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY');
    $tables = [];
    $ignored = [];
    foreach ($meta as $table) {
        $name = $table['TABLE_NAME'];
        if (!preg_match('/^[a-zA-Z0-9_]+$/D', $name)) { throw new RuntimeException('Unsupported table'); }
        if (in_array($name, ['sessions','password_resets','schema_migrations','migrations','login_attempts'], true)) {
            $ignored[] = $name; continue;
        }
        if ($table['ENGINE'] !== 'InnoDB') { throw new RuntimeException('A transactional source is required'); }
        $tables[$name] = $pdo->query('SELECT * FROM `'.$name.'`')->fetchAll(PDO::FETCH_ASSOC);
    }
    $pdo->rollBack();
    echo json_encode(['tables'=>$tables, 'ignored'=>$ignored], JSON_THROW_ON_ERROR);
} catch (Throwable $e) { fwrite(STDERR, 'Read-only export failed.'); exit(1); }
''';
