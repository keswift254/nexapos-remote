import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/user_role.dart';
import '../../domain/services/clock_health_service.dart';
import '../../domain/services/session_service.dart';

/// The dashboard's warning that this device's clock (or time zone) is wrong -
/// nothing at all while it is fine, or while it has not been possible to tell.
/// The admin can tap it to fix things (Settings > Region and Time); anyone else
/// is told to ask the admin.
class ClockHealthBanner extends ConsumerWidget {
  const ClockHealthBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(clockHealthProvider);
    if (health == null || !health.hasProblem) return const SizedBox.shrink();
    final isAdmin = ref.watch(sessionProvider)?.role == UserRole.admin;

    final skew = health.skew;
    final what = health.timeIsWrong && skew != null
        ? "This device's clock is ${describeClockDifference(skew)} "
              '${skew.isNegative ? 'behind' : 'ahead of'} the real time, so '
              'receipts and reports show the wrong time.'
        : "This device's time zone does not match your shop's region.";
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('clock-health-banner'),
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text("This device's clock looks wrong"),
          subtitle: Text(
            isAdmin ? '$what Tap to fix it.' : '$what Ask the shop admin to fix it.',
          ),
          onTap: isAdmin ? () => context.push('/region-time') : null,
        ),
      ),
    );
  }
}
