import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/background_service.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/settings_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/services/storage_target.dart';
import 'package:local_drop/state/server_controller.dart';

import '../fakes/fake_background_service.dart';
import '../fakes/fake_network_service.dart';
import '../fakes/fake_server_service.dart';

class _Media implements MediaStoreAdapter {
  _Media(this.supported);
  final bool supported;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<void> saveToDownloads(File source, String name) async {}
}

void main() {
  late Directory tmp;
  late FakeBackgroundService bg;
  late FakeServerService server;
  late SettingsService settings;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_bg_');
    bg = FakeBackgroundService();
    settings = SettingsService(File('${tmp.path}/settings.json'));
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<ServerController> running({bool downloads = true}) async {
    final network = FakeNetworkService();
    final c = ServerController(
      network: network,
      storage: StorageService(Directory('${tmp.path}/r')),
      createServer: (s) => server = FakeServerService(s),
      background: bg,
      settings: settings,
      mediaStore: _Media(downloads),
    );
    network.controller.add(const Connected('192.168.1.20'));
    await Future<void>.delayed(Duration.zero);
    await c.start();
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('start → bildirim IP:PORT ile başlar, uyarı yok', () async {
    final c = await running();
    expect(bg.started, ['192.168.1.20:8080']);
    expect(c.notice, isNull);
    c.dispose();
  });

  test('bildirim izni reddi → sunucu çalışır, uyarı görünür', () async {
    bg.permissionGranted = false;
    final c = await running();
    expect(c.status, ServerStatus.running);
    expect(c.notice, contains('Bildirim izni yok'));
    c.dispose();
  });

  test('servis başlatılamazsa sunucu yine çalışır, uyarı', () async {
    bg.startError = 'Arka plan servisi başlatılamadı';
    final c = await running();
    expect(c.status, ServerStatus.running);
    expect(c.notice, 'Arka plan servisi başlatılamadı');
    c.dispose();
  });

  test('bildirimdeki Durdur → sunucu ve servis kapanır', () async {
    final c = await running();
    bg.eventsController.add(BackgroundEvent.stopPressed);
    await settle();
    expect(c.status, ServerStatus.stopped);
    expect(server.isRunning, isFalse);
    expect(bg.stopCalls, 1);
    expect(c.notice, isNull);
    c.dispose();
  });

  test('süre doldu → sunucu kapanır, "Süre doldu, tekrar başlat"', () async {
    final c = await running();
    bg.eventsController.add(BackgroundEvent.timeout);
    await settle();
    expect(c.status, ServerStatus.error);
    expect(c.errorMessage, 'Süre doldu, tekrar başlat');
    expect(server.isRunning, isFalse);
    expect(c.canStart, isTrue);
    c.dispose();
  });

  test('kayıt yeri ayarı ve İndirilenler desteği', () async {
    final c = await running();
    await settle();
    expect(c.downloadsSupported, isTrue);
    expect(c.saveLocation, SaveLocation.appFolder);
    await c.setSaveLocation(SaveLocation.downloads);
    expect(c.saveLocation, SaveLocation.downloads);
    expect(settings.saveLocation, SaveLocation.downloads);
    c.dispose();
  });

  test('Android 10 altı → İndirilenler desteklenmez', () async {
    final c = await running(downloads: false);
    await settle();
    expect(c.downloadsSupported, isFalse);
    c.dispose();
  });
}
