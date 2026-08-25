import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../licensing/license_gateway.dart' show licenseServerBaseUrl;
import '../payments/platform_http_client.dart';

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}

/// Distinguished from [UpdateException] the same way
/// LicenseOfflineException is - so the periodic background check (see
/// app.dart) can stay silent on "no internet right now" while still
/// surfacing a real server-side problem if the user explicitly taps
/// "Check for Updates".
class UpdateOfflineException implements Exception {
  const UpdateOfflineException();
}

class LatestVersionInfo {
  final String version;
  final String windowsUrl;
  final String androidUrl;
  final String? releaseNotes;
  // Hex-encoded SHA-256 of the exact file at windowsUrl/androidUrl,
  // computed by whoever cuts the release (see generator.html's publish
  // card) and checked against the downloaded bytes before anything is
  // extracted or installed - see UpdateService.install(). Nullable so a
  // version published before this existed doesn't crash parsing; the
  // install path treats an absent hash as "skip verification", not as
  // a failure, since older/rolled-back server data shouldn't brick
  // updating.
  final String? windowsSha256;
  final String? androidSha256;

  const LatestVersionInfo({
    required this.version,
    required this.windowsUrl,
    required this.androidUrl,
    this.releaseNotes,
    this.windowsSha256,
    this.androidSha256,
  });
}

/// Talks to nexapos_license's latest_version/set_latest_version endpoints
/// (the vendor's key-generator server, see license_gateway.dart's doc for
/// why this is a fixed vendor-operated address rather than a per-shop
/// setting). Reuses platform_http_client's request plumbing exactly like
/// LicenseGateway does for the JSON call; the actual file download is
/// separate (see [downloadTo]) since that's a raw byte stream, not JSON.
class UpdateGateway {
  final http.Client _client;

  UpdateGateway([http.Client? client]) : _client = client ?? http.Client();

  /// Returns null if the vendor hasn't published a version yet (a valid,
  /// expected state right after this feature first ships - not an error
  /// to surface to the user) rather than throwing for that specific case.
  Future<LatestVersionInfo?> fetchLatestVersion() async {
    Map<String, dynamic> response;
    try {
      response = await platformRequest(_client, 'GET', 'latest_version', licenseServerBaseUrl);
    } on PaystackOfflineException {
      throw const UpdateOfflineException();
    } on PaystackException catch (e) {
      if (e.message.contains('No version has been published yet')) return null;
      throw UpdateException(e.message);
    }
    if (response['success'] != true) return null;
    final version = (response['version'] as String? ?? '').trim();
    if (version.isEmpty) return null;
    final windowsSha256 = (response['windows_sha256'] as String?)?.trim();
    final androidSha256 = (response['android_sha256'] as String?)?.trim();
    return LatestVersionInfo(
      version: version,
      windowsUrl: (response['windows_url'] as String? ?? '').trim(),
      androidUrl: (response['android_url'] as String? ?? '').trim(),
      releaseNotes: (response['release_notes'] as String?)?.trim(),
      windowsSha256: (windowsSha256 == null || windowsSha256.isEmpty) ? null : windowsSha256,
      androidSha256: (androidSha256 == null || androidSha256.isEmpty) ? null : androidSha256,
    );
  }

  /// Streams [url] straight to [destination] rather than buffering the
  /// whole file in memory first - a Windows build zip is tens of MB, and
  /// this runs on the same phones/low-end Windows machines the rest of
  /// the app targets. [onProgress] reports (bytesReceived, totalBytes);
  /// totalBytes is null if the server didn't send Content-Length.
  Future<void> downloadTo(
    String url,
    File destination, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    // The whole point of the update mechanism is executing whatever
    // this downloads (Windows: extracted and copied over the live
    // install; Android: handed to the OS installer) - refusing
    // anything but HTTPS here closes off plain on-path tampering as an
    // attack vector, independent of the checksum check the caller also
    // does. Checked here, not at parse time in fetchLatestVersion, so
    // a bad URL for one platform doesn't block a good one for the other.
    if (uri.scheme != 'https') {
      throw const UpdateException('The update download URL is not secure (not HTTPS) - refusing to download it.');
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(http.Request('GET', uri)).timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw const UpdateOfflineException();
    } on SocketException {
      throw const UpdateOfflineException();
    } on http.ClientException {
      throw const UpdateOfflineException();
    }
    if (response.statusCode >= 400) {
      throw UpdateException('Could not download the update (server said ${response.statusCode}).');
    }

    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
      await sink.flush();
    } on SocketException {
      throw const UpdateOfflineException();
    } finally {
      await sink.close();
    }
  }
}
