import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/network_service.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/state/server_controller.dart';

import '../fakes/fake_network_service.dart';
import '../fakes/fake_server_service.dart';

void main() {
  late Directory tmp;
  late StorageService storage;
  late FakeServerService server;
  late ServerController c;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_events_');
    storage = StorageService(Directory('${tmp.path}/r'));
    await storage.ensureExists();
    final network = FakeNetworkService();
    c = ServerController(
      network: network,
      storage: storage,
      createServer: (s, _) => server = FakeServerService(s),
    );
    network.controller.add(const Connected('192.168.1.20'));
    await Future<void>.delayed(Duration.zero);
    await c.start();
  });

  tearDown(() async {
    c.dispose();
    await tmp.delete(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('start: url ve PIN fake sunucudan', () {
    expect(c.status, ServerStatus.running);
    expect(c.url, 'http://192.168.1.20:8080/?t=Tok3nTok3nTok3n1');
    expect(c.pin, '123456');
  });

  test('textReceived → lastText; clearText → null', () async {
    server.emit(const TextReceived('merhaba'));
    await settle();
    expect(c.lastText, 'merhaba');
    c.clearText();
    expect(c.lastText, isNull);
  });

  test('olaylar UI akışına iletilir', () async {
    final received = <ServerEvent>[];
    final sub = c.events.listen(received.add);
    server.emit(const FileUploaded('a.txt', 3));
    await settle();
    expect(received.single, isA<FileUploaded>());
    await sub.cancel();
  });

  test('uploaded → dosya listesi yenilenir', () async {
    expect(c.files, isEmpty);
    await storage.resolve('a.txt').writeAsString('abc');
    server.emit(const FileUploaded('a.txt', 3));
    await settle();
    expect(c.files.map((f) => f.name), ['a.txt']);
  });

  test('stop → url/pin null, lastText korunur', () async {
    server.emit(const TextReceived('x'));
    await settle();
    await c.stop();
    expect(c.status, ServerStatus.stopped);
    expect(c.url, isNull);
    expect(c.pin, isNull);
    expect(c.lastText, 'x');
  });

  test('importFile: akışla klasöre kopyalar, aynı ad → (1)', () async {
    final first = await c.importFile('rapor.pdf', Stream.value([1, 2, 3]));
    final second = await c.importFile('rapor.pdf', Stream.value([4]));
    expect(first, 'rapor.pdf');
    expect(second, 'rapor (1).pdf');
    expect(c.files.map((f) => f.name), ['rapor (1).pdf', 'rapor.pdf']);
    expect(await storage.resolve('rapor.pdf').readAsBytes(), [1, 2, 3]);
  });

  test('importFile: akış hatası → .part kalmaz, liste değişmez', () async {
    await expectLater(
      c.importFile('bozuk.bin', Stream.error(const FileSystemException('x'))),
      throwsA(isA<FileSystemException>()),
    );
    expect(storage.root.listSync(), isEmpty);
    expect(c.files, isEmpty);
  });

  test('deleteFile: siler ve listeyi yeniler; olmayan → false', () async {
    await c.importFile('sil.txt', Stream.value([1]));
    expect(await c.deleteFile('sil.txt'), isTrue);
    expect(c.files, isEmpty);
    expect(await c.deleteFile('sil.txt'), isFalse);
  });
}
