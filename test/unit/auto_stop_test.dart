import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/settings_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/state/auto_stop_policy.dart';
import 'package:local_drop/state/server_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_background_service.dart';
import '../fakes/fake_network_service.dart';
import '../fakes/fake_server_service.dart';

void main() {
  late DateTime now;

  setUp(() => now = DateTime(2026, 10, 9, 12));

  group('AutoStopPolicy (saf)', () {
    late Duration timeout;
    late AutoStopPolicy policy;

    setUp(() {
      timeout = const Duration(minutes: 15);
      policy = AutoStopPolicy(timeout: () => timeout, now: () => now)
        ..serverStarted();
    });

    test('15 dk transfer yok → stop', () {
      now = now.add(const Duration(minutes: 14, seconds: 59));
      expect(policy.shouldStop(), isFalse);
      now = now.add(const Duration(seconds: 1));
      expect(policy.shouldStop(), isTrue);
    });

    test('transfer süreyi sıfırlar; sürerken asla durmaz', () {
      now = now.add(const Duration(minutes: 10));
      policy.begin();
      now = now.add(const Duration(hours: 1));
      expect(policy.shouldStop(), isFalse, reason: 'aktif transfer');
      policy.end();
      now = now.add(const Duration(minutes: 14));
      expect(policy.shouldStop(), isFalse);
      now = now.add(const Duration(minutes: 1));
      expect(policy.shouldStop(), isTrue);
    });

    test('kapalı (0) veya sunucu durmuş → hiç', () {
      timeout = Duration.zero;
      now = now.add(const Duration(days: 1));
      expect(policy.shouldStop(), isFalse);

      timeout = const Duration(minutes: 15);
      policy.serverStopped();
      expect(policy.shouldStop(), isFalse);
    });
  });

  group('controller', () {
    late Directory tmp;
    late FakeServerService server;
    late FakeBackgroundService bg;
    late ServerController c;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ld_autostop_');
      SharedPreferences.setMockInitialValues({'autoStopMinutes': 15});
      final network = FakeNetworkService();
      bg = FakeBackgroundService();
      c = ServerController(
        network: network,
        storage: StorageService(Directory('${tmp.path}/r')),
        settings: await SettingsService.load(),
        background: bg,
        clock: () => now,
        createServer: (s, _) => server = FakeServerService(s),
      );
      network.controller.add(const Connected('192.168.1.5'));
      await Future<void>.delayed(Duration.zero);
      await c.start();
    });

    tearDown(() async {
      c.dispose();
      await tmp.delete(recursive: true);
    });

    test(
      '15 dk boşta → sunucu ve bildirim kapanır, AutoStopped olayı',
      () async {
        final events = <ServerEvent>[];
        final sub = c.events.listen(events.add);

        now = now.add(const Duration(minutes: 14));
        await c.checkAutoStop();
        expect(c.status, ServerStatus.running);

        now = now.add(const Duration(minutes: 1));
        await c.checkAutoStop();
        await Future<void>.delayed(Duration.zero);
        expect(c.status, ServerStatus.stopped);
        expect(server.isRunning, isFalse);
        expect(bg.stopCalls, 1);
        expect(events.whereType<AutoStopped>(), hasLength(1));
        await sub.cancel();
      },
    );

    test('ayar 0 (kapalı) → kapanmaz', () async {
      await c.setAutoStopMinutes(0);
      now = now.add(const Duration(days: 1));
      await c.checkAutoStop();
      expect(c.status, ServerStatus.running);
    });

    test('her başlatmada yeni sunucu (port ayarı uygulanır)', () async {
      final first = server;
      await c.stop();
      await c.start();
      expect(identical(server, first), isFalse);
      expect(server.isRunning, isTrue);
    });
  });
}
