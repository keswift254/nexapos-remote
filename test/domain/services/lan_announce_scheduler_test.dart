import 'dart:async';
import 'dart:io';

// ignore: depend_on_referenced_packages - ships with flutter_test
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/domain/services/lan_announce_scheduler.dart';

void main() {
  group('LanAnnounceScheduler', () {
    test('announces once, shortly after a change - not at the next heartbeat', () {
      fakeAsync((async) {
        var announced = 0;
        final scheduler = LanAnnounceScheduler(() async => announced++);

        scheduler.changed();
        async.elapse(const Duration(milliseconds: 60));
        expect(announced, 0, reason: 'a short pause first, so a burst of writes is one announcement');
        async.elapse(const Duration(milliseconds: 100));
        expect(announced, 1);
        scheduler.dispose();
      });
    });

    test('a burst of changes (a sale writes several tables) is ONE announcement', () {
      fakeAsync((async) {
        var announced = 0;
        final scheduler = LanAnnounceScheduler(() async => announced++);

        for (var i = 0; i < 6; i++) {
          scheduler.changed();
          async.elapse(const Duration(milliseconds: 20));
        }
        async.elapse(const Duration(milliseconds: 500));

        expect(announced, 1);
        scheduler.dispose();
      });
    });

    test('a change that happens WHILE an announcement is being built triggers one more', () {
      fakeAsync((async) {
        var announced = 0;
        final build = <Completer<void>>[];
        final scheduler = LanAnnounceScheduler(() {
          announced++;
          final c = Completer<void>();
          build.add(c);
          return c.future;
        });

        scheduler.changed();
        async.elapse(const Duration(milliseconds: 200));
        expect(announced, 1, reason: 'the first announcement is being built');
        scheduler.changed(); // it may already have missed this one
        async.elapse(const Duration(milliseconds: 500));
        expect(announced, 1, reason: 'not overlapping');

        build.first.complete();
        async.flushMicrotasks();
        expect(announced, 2, reason: 'the newest state is announced right after');
        build.last.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(announced, 2, reason: 'and then it stops');
        scheduler.dispose();
      });
    });

    test('a failed announcement does not stop later ones', () {
      fakeAsync((async) {
        var announced = 0;
        final scheduler = LanAnnounceScheduler(() async {
          announced++;
          if (announced == 1) throw const SocketException('no route');
        });

        scheduler.changed();
        async.elapse(const Duration(milliseconds: 300));
        scheduler.changed();
        async.elapse(const Duration(milliseconds: 300));

        expect(announced, 2);
        scheduler.dispose();
      });
    });

    test('nothing is announced after it is disposed', () {
      fakeAsync((async) {
        var announced = 0;
        final scheduler = LanAnnounceScheduler(() async => announced++);

        scheduler.changed();
        scheduler.dispose();
        async.elapse(const Duration(seconds: 1));
        scheduler.changed();
        async.elapse(const Duration(seconds: 1));

        expect(announced, 0);
      });
    });
  });

  group('lanBroadcastTargets', () {
    List<String> targets(List<String> local) =>
        lanBroadcastTargets(local.map(InternetAddress.new)).map((a) => a.address).toList();

    test('one adapter: its own broadcast address AND the limited broadcast', () {
      expect(targets(['192.168.1.23']), ['192.168.1.255', '255.255.255.255']);
    });

    test('several adapters (Ethernet + Wi-Fi + a virtual switch): each network gets the announcement', () {
      expect(
        targets(['192.168.1.23', '10.0.5.7', '172.20.144.1']),
        ['192.168.1.255', '10.0.5.255', '172.20.144.255', '255.255.255.255'],
      );
    });

    test('two addresses on the same network are one target', () {
      expect(targets(['192.168.1.23', '192.168.1.40']), ['192.168.1.255', '255.255.255.255']);
    });

    test('addresses that are not a shop network (public, link-local, loopback) get no directed broadcast', () {
      expect(targets(['8.8.4.4', '169.254.3.9', '127.0.0.1']), ['255.255.255.255']);
    });

    test('the private 172 range is only 172.16 to 172.31', () {
      expect(targets(['172.15.0.4', '172.32.0.4']), ['255.255.255.255']);
      expect(targets(['172.16.0.4', '172.31.0.4']), ['172.16.0.255', '172.31.0.255', '255.255.255.255']);
    });

    test('with no addresses at all it is still the limited broadcast, as before', () {
      expect(targets([]), ['255.255.255.255']);
    });

    test('IPv6 addresses are ignored', () {
      expect(targets(['fe80::1', '192.168.0.10']), ['192.168.0.255', '255.255.255.255']);
    });

    test('a host whose own address ends in .255 does not list itself', () {
      expect(targets(['192.168.0.255']), ['255.255.255.255']);
    });
  });
}
