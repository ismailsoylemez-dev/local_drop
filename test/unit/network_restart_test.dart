import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/wakelock_policy.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/state/network_restart_policy.dart';
import 'package:local_drop/state/server_controller.dart';

import '../fakes/fake_background_service.dart';
import '../fakes/fake_network_service.dart';
import '../fakes/fake_server_service.dart';

void main() {
  group('NetworkRestartPolicy (saf)', () {
    late List<String> restarts;
    late NetworkRestartPolicy policy;

    setUp(() {
      restarts = [];
      policy = NetworkRestartPolicy(restart: restarts.add)
        ..serverStarted('192.168.1.5');
    });

    test('IP değişti + aktif transfer 0 → restart', () {
      policy.onNetwork(const Connected('192.168.1.9'));
      expect(restarts, ['192.168.1.9']);
    });

    test('aktif transfer 1 → bekler; 0 olunca restart', () {
      policy
        ..begin()
        ..onNetwork(const Connected('10.0.0.3'));
      expect(restarts, isEmpty);
      expect(policy.pendingIp, '10.0.0.3');
      policy.end();
      expect(restarts, ['10.0.0.3']);
      expect(policy.pendingIp, isNull);
    });

    test(
      'aynı IP veya NoNetwork → restart yok; eski IP geri gelirse iptal',
      () {
        policy
          ..onNetwork(const Connected('192.168.1.5'))
          ..onNetwork(const NoNetwork());
        expect(restarts, isEmpty);

        policy
          ..begin()
          ..onNetwork(const Connected('10.0.0.3'))
          ..onNetwork(const Connected('192.168.1.5'))
          ..end();
        expect(restarts, isEmpty);
      },
    );

    test('sunucu kapalıyken IP değişimi yok sayılır', () {
      policy
        ..serverStopped()
        ..onNetwork(const Connected('10.0.0.3'));
      expect(restarts, isEmpty);
    });

    test('restart sonrası yeni IP sunulan IP olur', () {
      policy.onNetwork(const Connected('10.0.0.3'));
      policy.onNetwork(const Connected('10.0.0.3'));
      expect(restarts, ['10.0.0.3']);
    });
  });

  group('controller', () {
    late Directory tmp;
    late FakeNetworkService network;
    late FakeServerService server;
    late FakeBackgroundService bg;
    late TransferObserver transfers;
    late ServerController c;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ld_restart_');
      network = FakeNetworkService();
      bg = FakeBackgroundService();
      c = ServerController(
        network: network,
        storage: StorageService(Directory('${tmp.path}/r')),
        background: bg,
        createServer: (s, t) {
          transfers = t;
          return server = FakeServerService(s);
        },
      );
      network.controller.add(const Connected('192.168.1.5'));
      await Future<void>.delayed(Duration.zero);
      await c.start();
    });

    tearDown(() async {
      c.dispose();
      await tmp.delete(recursive: true);
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test(
      'IP değişti → yeni URL, bildirim güncel, NetworkChanged olayı',
      () async {
        final events = <ServerEvent>[];
        final sub = c.events.listen(events.add);
        server.startCount = 0;

        network.controller.add(const Connected('10.0.0.7'));
        await settle();

        expect(c.status, ServerStatus.running);
        expect(c.url, startsWith('http://10.0.0.7:8080/?t='));
        expect(server.startCount, 1, reason: 'yeniden başlatıldı');
        expect(bg.updated, ['10.0.0.7:8080']);
        expect(events.whereType<NetworkChanged>().single.ip, '10.0.0.7');
        await sub.cancel();
      },
    );

    test('aktif transfer varken ertelenir, bitince yeniden başlar', () async {
      server.startCount = 0;
      transfers.begin();
      expect(c.activeTransfers, 1);

      network.controller.add(const Connected('10.0.0.7'));
      await settle();
      expect(server.startCount, 0);
      expect(c.url, startsWith('http://192.168.1.5:'));

      transfers.end();
      await settle();
      expect(server.startCount, 1);
      expect(c.url, startsWith('http://10.0.0.7:'));
    });

    test('yeniden başlatma hatası → error, servis durur', () async {
      server.failNextStart = true;
      network.controller.add(const Connected('10.0.0.7'));
      await settle();
      expect(c.status, ServerStatus.error);
      expect(c.errorMessage, 'Ağ değişti, sunucu yeniden başlatılamadı');
      expect(bg.stopCalls, 1);
    });
  });
}
