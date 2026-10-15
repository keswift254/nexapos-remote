import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/services/session_service.dart';
import '../../domain/services/sync_health_notice.dart';
import '../../domain/services/sync_service.dart';

/// What the dashboard should warn about, if anything. Looked at again every few
/// minutes; any failure to look just means no warning.
final syncNoticeProvider = FutureProvider.autoDispose<SyncNotice?>((ref) async {
  final health = await ref.read(syncServiceProvider).health();
  return syncNoticeFor(health, DateTime.now());
});

final quarantineGroupsProvider = FutureProvider.autoDispose<List<QuarantineGroup>>(
  (ref) => ref.read(syncServiceProvider).quarantineGroups(),
);

/// The dashboard's warning that this device's data is not reaching the cloud, or
/// that the server refused some of it. Nothing at all while all is well.
class SyncHealthBanner extends ConsumerStatefulWidget {
  const SyncHealthBanner({super.key, this.lookAgainEvery = const Duration(minutes: 10)});

  final Duration lookAgainEvery;

  @override
  ConsumerState<SyncHealthBanner> createState() => _SyncHealthBannerState();
}

class _SyncHealthBannerState extends ConsumerState<SyncHealthBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.lookAgainEvery, (_) {
      if (mounted) ref.invalidate(syncNoticeProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showDetails(BuildContext context, SyncNotice notice) {
    final isAdmin = ref.read(sessionProvider)?.role == UserRole.admin;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notice.title),
        content: SingleChildScrollView(
          child: Consumer(
            builder: (context, ref, _) {
              final groups = ref.watch(quarantineGroupsProvider).asData?.value ?? const <QuarantineGroup>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.message.replaceAll(' Tap for details.', '')),
                  if (notice.kind == SyncNoticeKind.rowsRefused && groups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('What the server said:'),
                    const SizedBox(height: 4),
                    for (final group in groups)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${group.count} x ${group.tableName}: ${group.reason}'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Nothing has been deleted. Tell NexaPOS support if this stays.'),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            key: const Key('sync-health-close'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (isAdmin)
            FilledButton(
              key: const Key('sync-health-open-device-sync'),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/device-sync');
              },
              child: const Text('Open Device Sync'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(syncNoticeProvider).asData?.value;
    if (notice == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('sync-health-banner'),
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(notice.kind == SyncNoticeKind.notUploading ? Icons.cloud_off : Icons.error_outline),
          title: Text(notice.title),
          subtitle: Text(notice.message),
          onTap: () => _showDetails(context, notice),
        ),
      ),
    );
  }
}
