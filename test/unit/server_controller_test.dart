import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/errors.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/server_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/state/server_controller.dart';

import '../fakes/fake_network_service.dart';

void main() {
  late Directory tmp;
  late StorageService storage;
  late FakeNetworkService network;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_ctrl_');
    storage = StorageService(Directory('${tmp.path}/r'));
    network = FakeNetworkService();
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<ServerController> connected(ServerFactory factory) async {
    final c = ServerController(
      network: network,
      storage: storage,
      createServer: factory,
    );
    network.controller.add(const Connected('192.168.1.20'));
    await Future<void>.delayed(Duration.zero);
    return c;
  }

  test(
    'start → running, url ağ IP + port + token, PIN; stop → temiz',
    () async {
      late ServerService server;
      final c = await connected(
        (s) => server = ServerService(
          storage: s,
          address: InternetAddress.loopbackIPv4,
          portStart: 0,
          portEnd: 0,
        ),
      );

      await c.start();
      expect(c.status, ServerStatus.running);
      expect(c.url, 'http://192.168.1.20:${server.port}/?t=${server.token}');
      expect(c.pin, matches(RegExp(r'^\d{6}$')));
      expect(c.canStart, isFalse);

      await c.stop();
      expect(c.status, ServerStatus.stopped);
      expect(c.url, isNull);
      expect(c.pin, isNull);
      expect(server.isRunning, isFalse);
      c.dispose();
    },
  );

  test('ServerStartException → error + mesaj, tekrar başlatılabilir', () async {
    final c = await connected(
      (_) => throw const ServerStartException('Port bulunamadı'),
    );
    await c.start();
    expect(c.status, ServerStatus.error);
    expect(c.errorMessage, 'Port bulunamadı');
    expect(c.url, isNull);
    expect(c.canStart, isTrue);
    c.dispose();
  });

  test('ağ yokken start çalışmaz', () async {
    var created = false;
    final c = ServerController(
      network: network,
      storage: storage,
      createServer: (_) {
        created = true;
        throw StateError('çağrılmamalı');
      },
    );
    network.controller.add(const NoNetwork());
    await Future<void>.delayed(Duration.zero);
    await c.start();
    expect(created, isFalse);
    expect(c.status, ServerStatus.stopped);
    c.dispose();
  });
}
