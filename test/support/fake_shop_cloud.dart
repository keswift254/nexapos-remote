import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The shop server's sync as it really behaves (publish-platform public/index.php push_changes / pull_changes and
/// MaintenanceService), for tests that put several devices through it:
///  - push_changes: all or nothing per request; every (source device, revision) is kept once; the same revision sent
///    again is fine when it matches (for products apart from stockQty, imagePath and updatedAt) and a clash otherwise
///    (422, with the highest revision held for that device); a change dated more than a day after [now] is refused; a
///    relayed change is refused when its source device is not an active device of the shop;
///  - pull_changes: every change after the cursor, 500 at a time, the device's own included;
///  - [compact]: the daily clean-up, which keeps only the newest event of every row.
class FakeShopCloud {
  FakeShopCloud({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// The server's clock (for the "more than a day in the future" check).
  DateTime Function() now;

  final changes = <Map<String, dynamic>>[];
  final _byRevision = <String, Map<String, dynamic>>{};
  var _nextId = 1;

  /// Devices of the shop that may be the source of a relayed change. Empty: any.
  final activeDevices = <String>{};

  /// When false, nothing gets through: the internet is down for every device.
  bool online = true;

  /// Devices without internet right now (their requests fail as they do offline).
  final noInternet = <String>{};

  var pushRequests = 0;
  var pullRequests = 0;

  /// Every push_changes body each device sent (for tests that look at what went up).
  final pushedBy = <String, List<List<Map<String, dynamic>>>>{};

  static const _deviceLocal = {
    'products': {'stockQty', 'imagePath', 'updatedAt'},
  };

  /// How many revisions the server holds for [device].
  int heldFor(String device) => _byRevision.keys.where((k) => k.startsWith('$device/')).length;

  /// The server's newest copy of [rowId] in [table].
  Map<String, dynamic>? latest(String table, String rowId) {
    Map<String, dynamic>? best;
    for (final change in changes) {
      if (change['table_name'] == table && change['row_id'] == rowId) best = change;
    }
    return best == null ? null : best['payload'] as Map<String, dynamic>;
  }

  bool _same(Map<String, dynamic> held, Map<String, dynamic> sent) {
    final local = _deviceLocal[sent['table_name']] ?? const <String>{};
    if (held['table_name'] != sent['table_name'] || held['row_id'] != sent['row_id']) return false;
    if (!local.contains('updatedAt') && held['updated_at'] != sent['updated_at']) return false;
    String canonical(Map<String, dynamic> payload) {
      final keys = payload.keys.where((k) => !local.contains(k)).toList()..sort();
      return jsonEncode({for (final k in keys) k: payload[k]});
    }

    return canonical(held['payload'] as Map<String, dynamic>) == canonical(sent['payload'] as Map<String, dynamic>);
  }

  http.Response _refuse(String message, [Map<String, dynamic> extra = const {}]) => http.Response(
        jsonEncode({'success': false, 'message': 'Could not record changes: $message', ...extra}),
        422,
      );

  /// The daily clean-up: of every row, only its newest event stays.
  int compact() {
    final newest = <String, int>{};
    for (final change in changes) {
      newest['${change['table_name']}/${change['row_id']}'] = change['id'] as int;
    }
    final before = changes.length;
    changes.removeWhere((c) => newest['${c['table_name']}/${c['row_id']}'] != c['id']);
    return before - changes.length;
  }

  /// The http client [device] talks to the server with.
  http.Client client(String device) => MockClient((request) async {
        if (!online || noInternet.contains(device)) throw http.ClientException('No internet');
        final action = request.url.queryParameters['action'];
        if (action == 'pull_changes') {
          pullRequests++;
          final since = int.parse(request.url.queryParameters['since'] ?? '0');
          final page = changes.where((c) => (c['id'] as int) > since).take(500).toList();
          return http.Response(
            jsonEncode({
              'success': true,
              'changes': page,
              'next_cursor': page.isEmpty ? since : page.last['id'],
              'has_more': page.length == 500,
            }),
            200,
          );
        }
        if (action != 'push_changes') throw StateError('unexpected request: ${request.url}');
        pushRequests++;
        final sent = (jsonDecode(request.body)['changes'] as List).cast<Map<String, dynamic>>();
        (pushedBy[device] ??= []).add(sent);
        final fresh = <String, Map<String, dynamic>>{};
        for (final change in sent) {
          final payload = change['payload'] as Map<String, dynamic>;
          final source = (change['source_device_id'] as String?) ?? device;
          if (payload['id'] != change['row_id'] ||
              payload['localRev'] != change['local_rev'] ||
              payload['createdByDeviceId'] != source ||
              payload['updatedAt'] != change['updated_at']) {
            return _refuse('Malformed change entry.');
          }
          if (source != device && activeDevices.isNotEmpty && !activeDevices.contains(source)) {
            return _refuse('Relayed source device is not active in this shop.');
          }
          final at = DateTime.parse(change['updated_at'] as String);
          if (at.isAfter(now().add(const Duration(days: 1)))) {
            return _refuse("Change is dated more than a day in the future - check this device's date and time.");
          }
          final key = '$source/${change['local_rev']}';
          final held = _byRevision[key] ?? fresh[key];
          if (held != null) {
            if (_same(held, change)) continue;
            final max = _byRevision.keys
                .where((k) => k.startsWith('$source/'))
                .map((k) => int.parse(k.substring(source.length + 1)))
                .fold<int>(0, (a, b) => a > b ? a : b);
            return _refuse('A source revision was already recorded with different content.', {
              'reason': 'revision_clash',
              'source_device_id': source,
              'local_rev': change['local_rev'],
              'max_local_rev': max,
            });
          }
          fresh[key] = {...change, 'device_id': source};
        }
        for (final entry in fresh.entries) {
          _byRevision[entry.key] = entry.value;
          changes.add({
            'id': _nextId++,
            'table_name': entry.value['table_name'],
            'row_id': entry.value['row_id'],
            'device_id': entry.value['device_id'],
            'local_rev': entry.value['local_rev'],
            'updated_at': entry.value['updated_at'],
            'payload': entry.value['payload'],
          });
        }
        return http.Response(jsonEncode({'success': true, 'count': sent.length}), 200);
      });
}
