import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  final String windowsInstallerUrl;
  final String androidUrl;
  final String? releaseNotes;
  // Hex-encoded SHA-256 of the exact file at windowsInstallerUrl/androidUrl,
  // computed by whoever cuts the release (see generator.html's publish
  // card) and checked against the downloaded bytes before anything is
  // installed - see UpdateService.install(). Nullable only so old server
  // rows can still be parsed and shown; install refuses a release whose
  // checksum is absent or malformed.
  final String? windowsInstallerSha256;
  final String? androidSha256;
  // The Windows 7/8 edition's own installer for this same version, present
  // only when the release included one. Read by the legacy edition alone (see
  // kLegacyWindowsEdition); every other build ignores it.
  final String windowsLegacyInstallerUrl;
  final String? windowsLegacyInstallerSha256;

  // Delta-update fields: all optional, and only usable together with the
  // exact version this patch was built FROM - see UpdateService's
  // _tryAndroidPatch/_tryWindowsPatch, which fall back to a plain full
  // download (the fields above) whenever any of this is missing, doesn't
  // match the installed version, or fails to verify. patchFromVersion is
  // shared across platforms since a release publishes patches from the
  // SAME previous version for all of them together. androidPatch* is a
  // single bsdiff-style patch (nxpatch.dart) against this device's own
  // installed APK. windows*PatchUrl/Sha256 point at a small zip bundle
  // (nxpatch.dart's parseNxPatchManifest) covering every runtime file
  // that changed; patchApplierUrl/Sha256 is the small elevated helper
  // that copies the already-verified result into Program Files (see
  // release-tools/NexaPosPatchApply.cs) - stable across releases, so it
  // is published once and rarely needs to change.
  final String? patchFromVersion;
  final String? androidPatchUrl;
  final String? androidPatchSha256;
  final String? windowsInstallerPatchUrl;
  final String? windowsInstallerPatchSha256;
  final String? windowsLegacyInstallerPatchUrl;
  final String? windowsLegacyInstallerPatchSha256;
  final String? patchApplierUrl;
  final String? patchApplierSha256;

  const LatestVersionInfo({
    required this.version,
    this.windowsInstallerUrl = '',
    required this.androidUrl,
    this.releaseNotes,
    this.windowsInstallerSha256,
    this.androidSha256,
    this.windowsLegacyInstallerUrl = '',
    this.windowsLegacyInstallerSha256,
    this.patchFromVersion,
    this.androidPatchUrl,
    this.androidPatchSha256,
    this.windowsInstallerPatchUrl,
    this.windowsInstallerPatchSha256,
    this.windowsLegacyInstallerPatchUrl,
    this.windowsLegacyInstallerPatchSha256,
    this.patchApplierUrl,
    this.patchApplierSha256,
  });
}

/// Talks to nexapos_license's latest_version/set_latest_version endpoints
/// (the vendor's key-generator server, see license_gateway.dart's doc for
/// why this is a fixed vendor-operated address rather than a per-shop
/// setting). Reuses platform_http_client's request plumbing exactly like
/// LicenseGateway does for the JSON call; the actual file download is
/// separate (see [downloadTo]) since that's a raw byte stream, not JSON.
class UpdateGateway {
  static const int maxDownloadBytes = 512 * 1024 * 1024;

  final http.Client _client;

  UpdateGateway([http.Client? client]) : _client = client ?? http.Client();

  /// Returns null if the vendor hasn't published a version yet (a valid,
  /// expected state right after this feature first ships - not an error
  /// to surface to the user) rather than throwing for that specific case.
  Future<LatestVersionInfo?> fetchLatestVersion() async {
    Map<String, dynamic> response;
    try {
      response = await platformRequest(
        _client,
        'GET',
        'latest_version',
        licenseServerBaseUrl,
      );
    } on PaystackOfflineException {
      throw const UpdateOfflineException();
    } on PaystackException catch (e) {
      if (e.message.contains('No version has been published yet')) return null;
      throw UpdateException(e.message);
    }
    if (response['success'] != true) return null;
    final version = (response['version'] as String? ?? '').trim();
    if (version.isEmpty) return null;
    final windowsInstallerSha256 =
        (response['windows_installer_sha256'] as String?)?.trim();
    final androidSha256 = (response['android_sha256'] as String?)?.trim();
    final legacySha256 = (response['windows_legacy_installer_sha256'] as String?)
        ?.trim();
    String? clean(String key) {
      final value = (response[key] as String?)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }
    return LatestVersionInfo(
      version: version,
      windowsInstallerUrl: (response['windows_installer_url'] as String? ?? '')
          .trim(),
      androidUrl: (response['android_url'] as String? ?? '').trim(),
      releaseNotes: (response['release_notes'] as String?)?.trim(),
      windowsInstallerSha256:
          (windowsInstallerSha256 == null || windowsInstallerSha256.isEmpty)
          ? null
          : windowsInstallerSha256,
      androidSha256: (androidSha256 == null || androidSha256.isEmpty)
          ? null
          : androidSha256,
      windowsLegacyInstallerUrl:
          (response['windows_legacy_installer_url'] as String? ?? '').trim(),
      windowsLegacyInstallerSha256: (legacySha256 == null || legacySha256.isEmpty)
          ? null
          : legacySha256,
      patchFromVersion: clean('patch_from_version'),
      androidPatchUrl: clean('android_patch_url'),
      androidPatchSha256: clean('android_patch_sha256'),
      windowsInstallerPatchUrl: clean('windows_installer_patch_url'),
      windowsInstallerPatchSha256: clean('windows_installer_patch_sha256'),
      windowsLegacyInstallerPatchUrl: clean('windows_legacy_installer_patch_url'),
      windowsLegacyInstallerPatchSha256: clean('windows_legacy_installer_patch_sha256'),
      patchApplierUrl: clean('patch_applier_url'),
      patchApplierSha256: clean('patch_applier_sha256'),
    );
  }

  /// Downloads [url] fully into memory - only ever used for the small
  /// delta-update patch files (a few percent of the full app's size, see
  /// nxpatch.dart), never for a full APK/installer, which always goes
  /// through [downloadTo] instead so it streams straight to disk.
  Future<Uint8List> downloadBytes(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') {
      throw const UpdateException(
        'The update download URL is not secure (not HTTPS) - refusing to download it.',
      );
    }
    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(minutes: 2));
    } on TimeoutException {
      throw const UpdateOfflineException();
    } on SocketException {
      throw const UpdateOfflineException();
    } on http.ClientException {
      throw const UpdateOfflineException();
    }
    if (response.statusCode >= 400) {
      throw UpdateException(
        'Could not download the update patch (server said ${response.statusCode}).',
      );
    }
    if (response.bodyBytes.length > maxDownloadBytes) {
      throw const UpdateException(
        'The update patch is unexpectedly large - refusing to use it.',
      );
    }
    return response.bodyBytes;
  }

  /// Streams [url] straight to [destination] rather than buffering the
  /// whole file in memory first - a Windows setup exe is tens of MB, and
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
      throw const UpdateException(
        'The update download URL is not secure (not HTTPS) - refusing to download it.',
      );
    }

    http.StreamedResponse response;
    try {
      response = await _client
          .send(http.Request('GET', uri))
          .timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw const UpdateOfflineException();
    } on SocketException {
      throw const UpdateOfflineException();
    } on http.ClientException {
      throw const UpdateOfflineException();
    }
    if (response.statusCode >= 400) {
      throw UpdateException(
        'Could not download the update (server said ${response.statusCode}).',
      );
    }
    if (response.contentLength != null &&
        response.contentLength! > maxDownloadBytes) {
      throw const UpdateException(
        'The update download is unexpectedly large - refusing to save it.',
      );
    }

    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > maxDownloadBytes) {
          throw const UpdateException(
            'The update download is unexpectedly large - refusing to save it.',
          );
        }
        sink.add(chunk);
        onProgress?.call(received, response.contentLength);
      }
      await sink.flush();
    } on SocketException {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      throw const UpdateOfflineException();
    } on http.ClientException {
      // Same failure mode as a SocketException here - the connection
      // dropped mid-transfer (flaky wifi, a proxy/CDN closing an idle
      // or slow connection) - not something the user did wrong, so it
      // gets the same "try again" framing instead of leaking the raw
      // exception text through the generic catch below.
      await sink.close();
      if (await destination.exists()) await destination.delete();
      throw const UpdateOfflineException();
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
    await sink.close();
  }
}
