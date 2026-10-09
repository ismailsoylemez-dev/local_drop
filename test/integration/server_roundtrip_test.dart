import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/errors.dart';
import 'package:local_drop/services/server_service.dart';
import 'package:local_drop/services/storage_service.dart';

const _chunk = 64 * 1024;
const _boundary = 'ldintegrationboundary';

/// Konuma bağlı deterministik bayt; kayma/eksik bayt fark edilir.
int _byteAt(int pos, int seed) =>
    (pos ^ (pos >> 8) ^ (pos >> 16) ^ seed) & 0xff;

Stream<List<int>> _generate(int size, {int seed = 0}) async* {
  for (var offset = 0; offset < size; offset += _chunk) {
    final n = offset + _chunk > size ? size - offset : _chunk;
    final buf = Uint8List(n);
    for (var i = 0; i < n; i++) {
      buf[i] = _byteAt(offset + i, seed);
    }
    yield buf;
  }
}

/// Akışı üretici ile bayt bayt karşılaştırır (sha256 yerine; aynı veriyi
/// tekrar üretip doğrudan karşılaştırmak daha da sıkı).
Future<void> _expectContent(
  Stream<List<int>> data,
  int size, {
  int seed = 0,
}) async {
  var pos = 0;
  await for (final chunk in data) {
    for (final b in chunk) {
      if (b != _byteAt(pos, seed)) fail('bayt $pos farklı');
      pos++;
    }
  }
  expect(pos, size);
}

List<int> _head(String filename) => utf8.encode(
  '--$_boundary\r\n'
  'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
  'Content-Type: application/octet-stream\r\n\r\n',
);
final List<int> _tail = utf8.encode('\r\n--$_boundary--\r\n');

void main() {
  late Directory tmp;
  late StorageService storage;
  late ServerService server;
  late HttpClient client;

  Future<void> startServer({int maxFileBytes = 1 << 30}) async {
    server = ServerService(
      storage: storage,
      address: InternetAddress.loopbackIPv4,
      portStart: 0,
      portEnd: 0,
      maxFileBytes: maxFileBytes,
    );
    await server.start();
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_it_');
    storage = StorageService(
      Directory('${tmp.path}${Platform.pathSeparator}received'),
    );
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.dispose();
    await tmp.delete(recursive: true);
  });

  Uri url(String path) =>
      Uri.parse('http://127.0.0.1:${server.port}$path?t=${server.token}');

  Future<(int, String)> upload(
    String filename,
    int size, {
    int seed = 0,
  }) async {
    final req = await client.postUrl(url('/api/upload'));
    final head = _head(filename);
    req.headers.contentType = ContentType(
      'multipart',
      'form-data',
      parameters: {'boundary': _boundary},
    );
    req.contentLength = head.length + size + _tail.length;
    req.add(head);
    await req.addStream(_generate(size, seed: seed));
    req.add(_tail);
    final res = await req.close();
    return (res.statusCode, await utf8.decodeStream(res));
  }

  List<String> rootEntries() =>
      storage.root.listSync().map((e) => e.uri.pathSegments.last).toList();

  test('50 MB upload → listede → download birebir aynı', () async {
    await startServer();
    const size = 50 * 1024 * 1024;
    final (status, body) = await upload('buyuk.bin', size);
    expect(status, 200, reason: body);

    final listRes = await (await client.getUrl(url('/api/files'))).close();
    final list = jsonDecode(await utf8.decodeStream(listRes)) as List;
    expect(list.single, containsPair('name', 'buyuk.bin'));
    expect(list.single, containsPair('size', size));

    final res = await (await client.getUrl(url('/api/download/buyuk.bin')))
        .close();
    expect(res.statusCode, 200);
    expect(res.contentLength, size);
    await _expectContent(res, size);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('aynı adla ikinci upload → ad (1).ext', () async {
    await startServer();
    expect((await upload('a.txt', 10)).$1, 200);
    expect((await upload('a.txt', 20, seed: 1)).$1, 200);
    expect(rootEntries()..sort(), ['a (1).txt', 'a.txt']);
    await _expectContent(storage.resolve('a (1).txt').openRead(), 20, seed: 1);
  });

  test('upload ortasında soket kapanır → ne dosya ne .part kalır', () async {
    await startServer();
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port!,
    );
    final head = _head('yarim.bin');
    const declared = 10 * 1024 * 1024;
    socket.write(
      'POST /api/upload?t=${server.token} HTTP/1.1\r\n'
      'Host: 127.0.0.1\r\n'
      'Content-Type: multipart/form-data; boundary=$_boundary\r\n'
      'Content-Length: ${head.length + declared + _tail.length}\r\n\r\n',
    );
    socket.add(head);
    await socket.addStream(_generate(1024 * 1024));
    await socket.flush();
    // .part oluşana kadar bekle, sonra bağlantıyı kopar.
    final partSeen = await _waitFor(
      () => rootEntries().any((n) => n.endsWith('.part')),
    );
    expect(partSeen, isTrue);
    socket.destroy();

    final cleaned = await _waitFor(() => rootEntries().isEmpty);
    expect(cleaned, isTrue, reason: '${rootEntries()}');
  });

  test('limit aşımı → 413, .part yok', () async {
    await startServer(maxFileBytes: 1024);
    final (status, _) = await upload('buyuk.bin', 4096);
    expect(status, 413);
    expect(rootEntries(), isEmpty);
  });

  test('5 eşzamanlı aynı adlı upload → 5 doğru dosya', () async {
    await startServer();
    const size = 2 * 1024 * 1024;
    final results = await Future.wait([
      for (var i = 0; i < 5; i++) upload('es.bin', size),
    ]);
    expect(results.map((r) => r.$1), everyElement(200));
    final names = rootEntries()..sort();
    expect(names, [
      'es (1).bin',
      'es (2).bin',
      'es (3).bin',
      'es (4).bin',
      'es.bin',
    ]);
    for (final n in names) {
      await _expectContent(storage.resolve(n).openRead(), size);
    }
  });

  test('port doluysa bir sonrakine geçer, hepsi doluysa hata', () async {
    final busy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(busy.close);
    server = ServerService(
      storage: storage,
      address: InternetAddress.loopbackIPv4,
      portStart: busy.port,
      portEnd: busy.port + 10,
    );
    final port = await server.start();
    expect(port, isNot(busy.port));
    expect(port, inInclusiveRange(busy.port + 1, busy.port + 10));

    final full = ServerService(
      storage: storage,
      address: InternetAddress.loopbackIPv4,
      portStart: busy.port,
      portEnd: busy.port,
    );
    await expectLater(full.start(), throwsA(isA<ServerStartException>()));
    await full.dispose();
  });

  test('her start yeni token; stop sonrası bağlantı yok', () async {
    await startServer();
    final first = server.token;
    final port = server.port!;
    await server.stop();
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, port),
      throwsA(isA<SocketException>()),
    );
    await server.start();
    expect(server.token, isNot(first));
  });
}

Future<bool> _waitFor(
  bool Function() check, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (check()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return check();
}
