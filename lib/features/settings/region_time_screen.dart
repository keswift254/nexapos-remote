import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/region/regions.dart';
import '../../domain/services/clock_health_service.dart';
import '../../domain/services/date_settings_opener.dart';
import '../../domain/services/region_settings_service.dart';
import '../../domain/services/windows_time_fix_service.dart';
import '../region/region_picker.dart';

/// Settings > Region and Time: which country and time zone the shop is in, and
/// whether this device's clock agrees with the real time and with that zone.
///
/// A wrong clock matters to a shop: receipts and reports carry the wrong time,
/// day-end totals land on the wrong day, and a clock that is off by months
/// confuses every device it syncs with. NexaPOS compares the clock with the
/// license server's (see [TrustedTimeService]) in the background and warns on
/// the dashboard; this is where it is put right. On Windows the app can do that
/// itself (one permission prompt); on Android it can only open the system's
/// Date & time screen; elsewhere it says what to change.
class RegionTimeScreen extends ConsumerStatefulWidget {
  const RegionTimeScreen({super.key});

  @override
  ConsumerState<RegionTimeScreen> createState() => _RegionTimeScreenState();
}

class _RegionTimeScreenState extends ConsumerState<RegionTimeScreen> {
  RegionSettings? _saved;
  RegionSettings? _selected;
  bool _loaded = false;
  bool _saving = false;
  bool _checking = false;
  bool _fixing = false;
  String? _notice;
  bool _noticeIsError = false;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool get _isAndroid => canOpenDateSettings;

  bool get _dirty =>
      _selected != null &&
      (_saved == null ||
          _saved!.region.code != _selected!.region.code ||
          _saved!.zone.ianaId != _selected!.zone.ianaId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    RegionSettings? saved;
    try {
      saved = await ref.read(regionSettingsProvider.future);
    } catch (_) {}
    if (!mounted) return;
    final guess = suggestRegion(ref.read(deviceUtcOffsetProvider)());
    setState(() {
      _saved = saved;
      _selected = saved ?? RegionSettings(region: guess.region, zone: guess.zone);
      _loaded = true;
    });
    unawaited(_check(force: true));
  }

  Future<void> _check({bool force = false}) async {
    if (!mounted) return;
    setState(() => _checking = true);
    try {
      await ref.read(clockHealthProvider.notifier).check(force: force);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checking = false);
  }

  Future<void> _saveSelection() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(regionSettingsProvider.notifier).save(selected);
      if (!mounted) return;
      setState(() {
        _saved = selected;
        _notice = 'Region saved.';
        _noticeIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notice = 'Could not save the region: $e';
        _noticeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    await _check(force: true);
  }

  Future<void> _fix() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix the clock?'),
        content: const Text(
          'NexaPOS will read the real time from the internet and set this '
          "computer's clock (and the time zone you chose) to match. Windows "
          'will ask for permission first - choose Yes.\n\n'
          'It also switches on Windows\' automatic time sync, so the clock '
          'keeps itself right from now on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fix the clock'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    // The zone the person sees is the zone that gets set.
    if (_dirty) await _saveSelection();
    if (!mounted) return;
    setState(() {
      _fixing = true;
      _notice = null;
    });
    final result = await ref.read(windowsTimeFixServiceProvider).fixNow();
    if (!mounted) return;
    setState(() {
      _fixing = false;
      result.when(
        ok: (report) {
          _noticeIsError = false;
          _notice = report.warnings.isEmpty
              ? 'The clock is fixed.'
              : 'The clock is fixed. ${report.warnings.join(' ')}';
        },
        failure: (message) {
          _noticeIsError = true;
          _notice = message;
        },
      );
    });
  }

  Future<void> _openDateSettings() async {
    final opened = await ref.read(dateSettingsOpenerProvider)();
    if (!mounted || opened) return;
    setState(() {
      _noticeIsError = true;
      _notice =
          'Could not open the settings. Open your device\'s Settings, then '
          'Date & time, and turn on automatic date and time.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(clockHealthProvider);
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Region and Time')),
      body: !_loaded || selected == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Where is your shop?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'NexaPOS uses this to check that this device shows '
                          "your local time.",
                        ),
                        const SizedBox(height: 12),
                        RegionPicker(
                          selected: selected,
                          onChanged: (value) =>
                              setState(() => _selected = value),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            key: const Key('save-region'),
                            onPressed: _dirty && !_saving && !_fixing
                                ? _saveSelection
                                : null,
                            child: Text(
                              _saved == null ? 'Save region' : 'Save changes',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _ClockCard(
                      health: health,
                      checking: _checking,
                      fixing: _fixing,
                      regionSaved: _saved != null,
                      zone: (_saved ?? selected).zone,
                      isWindows: _isWindows,
                      isAndroid: _isAndroid,
                      onCheck: () => _check(force: true),
                      onFix: _fix,
                      onOpenSettings: _openDateSettings,
                    ),
                  ),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _notice!,
                    key: const Key('region-time-notice'),
                    style: TextStyle(
                      color: _noticeIsError
                          ? Theme.of(context).colorScheme.error
                          : Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ClockCard extends StatelessWidget {
  const _ClockCard({
    required this.health,
    required this.checking,
    required this.fixing,
    required this.regionSaved,
    required this.zone,
    required this.isWindows,
    required this.isAndroid,
    required this.onCheck,
    required this.onFix,
    required this.onOpenSettings,
  });

  final ClockHealth? health;
  final bool checking;
  final bool fixing;
  final bool regionSaved;
  final RegionZone zone;
  final bool isWindows;
  final bool isAndroid;
  final VoidCallback onCheck;
  final VoidCallback onFix;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final health = this.health;
    final lines = <Widget>[];

    Widget line(IconData icon, Color color, String text, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, key: key)),
        ],
      ),
    );

    final ok = Colors.green.shade700;
    final warn = Colors.orange.shade800;
    if (health == null) {
      lines.add(
        checking
            ? const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Checking the clock...'),
                ],
              )
            : const Text('The clock has not been checked yet.'),
      );
    } else {
      final skew = health.skew;
      if (skew == null) {
        lines.add(
          line(
            Icons.help_outline,
            theme.colorScheme.outline,
            kIsWeb
                ? "A web browser can't check the device clock."
                : 'Could not check the date and time (no internet '
                      'connection). It is checked again automatically when '
                      'this device is online.',
            key: const Key('clock-unknown'),
          ),
        );
      } else if (health.timeIsWrong) {
        lines.add(
          line(
            Icons.warning_amber_rounded,
            warn,
            "This device's clock is ${describeClockDifference(skew)} "
            '${skew.isNegative ? 'behind' : 'ahead of'} the real time.',
            key: const Key('clock-wrong'),
          ),
        );
      } else {
        lines.add(
          line(
            Icons.check_circle_outline,
            ok,
            'The date and time are correct.',
            key: const Key('clock-right'),
          ),
        );
      }
      if (health.zoneDiffers) {
        lines.add(
          line(
            Icons.warning_amber_rounded,
            warn,
            "This device's time zone "
            '(${formatUtcOffset(health.deviceOffset?.inMinutes ?? 0)}) does '
            'not match your region (${zone.label}).',
            key: const Key('zone-wrong'),
          ),
        );
      } else if (health.regionSet) {
        lines.add(
          line(
            Icons.check_circle_outline,
            ok,
            'The time zone matches your region.',
            key: const Key('zone-right'),
          ),
        );
      } else {
        lines.add(
          line(
            Icons.info_outline,
            theme.colorScheme.outline,
            'Save your region above so the time zone can be checked too.',
          ),
        );
      }
    }

    final hasProblem = health?.hasProblem ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Clock', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...lines,
        if (fixing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text('Waiting for Windows...'),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('check-clock'),
              onPressed: checking || fixing ? null : onCheck,
              child: const Text('Check now'),
            ),
            if (hasProblem && isWindows)
              FilledButton(
                key: const Key('fix-clock'),
                onPressed: checking || fixing ? null : onFix,
                child: const Text('Fix the clock now'),
              ),
            if (hasProblem && isAndroid)
              FilledButton(
                key: const Key('open-date-settings'),
                onPressed: onOpenSettings,
                child: const Text('Open Date & time settings'),
              ),
          ],
        ),
        if (hasProblem && !isWindows && !isAndroid) ...[
          const SizedBox(height: 8),
          const Text(
            "Set the correct date, time and time zone in this device's "
            'settings, and turn on automatic date and time.',
          ),
        ],
        if (hasProblem && isAndroid) ...[
          const SizedBox(height: 8),
          const Text(
            'Turn on "Automatic date & time" and "Automatic time zone" so it '
            'stays right.',
          ),
        ],
        if (isWindows) ...[
          const SizedBox(height: 8),
          Text(
            'NexaPOS checks the clock in the background. On Windows it can '
            'set the correct time for you - Windows asks for permission '
            'once - and turns on Windows\' own time sync so it stays right.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
