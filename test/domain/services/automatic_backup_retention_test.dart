import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/automatic_backup_service.dart';
import 'package:path/path.dart' as p;

File backup(DateTime time) => File('/backups/NexaPOS-auto-${time.millisecondsSinceEpoch}.nexabackup');

Set<String> names(Iterable<File> files) => files.map((f) => p.basename(f.path)).toSet();

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  test('a handful of backups is left alone', () {
    final files = [for (var i = 0; i < 4; i++) backup(now.subtract(Duration(hours: 6 * i)))];
    expect(backupFilesToDelete(files, now), isEmpty);
  });

  test('keeps the newest seven plus the newest of every day, deletes the rest', () {
    // Six-hour backups for four days: 16 files, four per day.
    final files = [for (var i = 0; i < 16; i++) backup(now.subtract(Duration(hours: 6 * i)))];
    final deleted = backupFilesToDelete(files, now);

    final kept = files.where((f) => !deleted.contains(f)).toList();
    // The newest seven...
    for (var i = 0; i < 7; i++) {
      expect(deleted, isNot(contains(files[i])), reason: 'newest seven are kept (index $i)');
    }
    // ...and every calendar day that has any backup still has one.
    String dayOf(File f) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        int.parse(RegExp(r'auto-(\d+)').firstMatch(p.basename(f.path))!.group(1)!),
        isUtc: true,
      );
      return '${time.year}-${time.month}-${time.day}';
    }
    final allDays = files.map(dayOf).toSet();
    expect(kept.map(dayOf).toSet(), allDays, reason: 'no day loses all of its backups');
    expect(allDays.length, 5);
    expect(deleted, isNotEmpty);
    expect(kept.length, lessThan(16));
  });

  test("the shop's real situation: a backup from before a problem survives a week of new ones", () {
    final lastGood = DateTime.utc(2026, 10, 8, 3, 12); // the last backup before the key was lost
    final afterwards = [for (var i = 0; i < 28; i++) DateTime.utc(2026, 10, 9).add(Duration(hours: 6 * i))];
    final files = [backup(lastGood), ...afterwards.map(backup)];
    final deleted = backupFilesToDelete(files, DateTime.utc(2026, 10, 16));
    expect(names(deleted), isNot(contains(p.basename(backup(lastGood).path))));
  });

  test('backups older than the daily window are deleted once they are not among the newest', () {
    final ancient = [for (var i = 0; i < 3; i++) backup(now.subtract(Duration(days: 40 + i)))];
    final recent = [for (var i = 0; i < 7; i++) backup(now.subtract(Duration(hours: 6 * i)))];
    final deleted = backupFilesToDelete([...ancient, ...recent], now);
    expect(deleted.toSet(), ancient.toSet());
  });

  test('files that are not ours are never deleted', () {
    final stranger = File('/backups/notes.txt');
    final broken = File('/backups/NexaPOS-auto-abc.nexabackup');
    final tooBig = File('/backups/NexaPOS-auto-99999999999999999999999.nexabackup');
    final recent = [for (var i = 0; i < 12; i++) backup(now.subtract(Duration(hours: 6 * i)))];
    final deleted = backupFilesToDelete([stranger, broken, tooBig, ...recent], now);
    expect(deleted, isNot(contains(stranger)));
    expect(deleted, isNot(contains(broken)));
    expect(deleted, isNot(contains(tooBig)));
  });

  test('the order the files are listed in does not matter', () {
    final files = [for (var i = 0; i < 30; i++) backup(now.subtract(Duration(hours: 5 * i)))];
    final forward = names(backupFilesToDelete(files, now));
    final backward = names(backupFilesToDelete(files.reversed.toList(), now));
    expect(backward, forward);
  });
}
