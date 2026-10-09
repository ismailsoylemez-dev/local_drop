import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/server_event.dart';

import 'handler_test_utils.dart';

void main() {
  late HandlerFixture f;

  setUp(() async => f = await HandlerFixture.create(maxFileBytes: 1024));
  tearDown(() => f.dispose());

  File inRoot(String name) =>
      File('${f.storage.root.path}${Platform.pathSeparator}$name');

  test('boş klasör → []', () async {
    final res = await f.send('GET', '/api/files');
    expect(res.statusCode, 200);
    expect(await readJson(res), <Object>[]);
  });

  test('liste ada göre sıralı, .part görünmez', () async {
    await inRoot('b.txt').writeAsString('bb');
    await inRoot('a.txt').writeAsString('a');
    await inRoot('.c.txt.part').writeAsString('yarım');
    final list = await readJson(await f.send('GET', '/api/files')) as List;
    expect(list.map((e) => (e as Map)['name']), ['a.txt', 'b.txt']);
    expect((list.first as Map)['size'], 1);
  });

  test('kök dışı dosya asla dönmez', () async {
    await File('${f.dir.path}${Platform.pathSeparator}secret')
        .writeAsString('gizli');
    for (final path in [
      '/api/download/..%2F..%2Fsecret',
      '/api/download/..%2Fsecret',
      '/api/download/..%5Csecret',
      '/api/download/%2e%2e%2fsecret',
    ]) {
      final res = await f.send('GET', path);
      expect([400, 404], contains(res.statusCode), reason: path);
      expect(await res.readAsString(), isNot(contains('gizli')), reason: path);
    }
  });

  test('olmayan dosya → 404', () async {
    final res = await f.send('GET', '/api/download/yok.txt');
    expect(res.statusCode, 404);
  });

  test('indirme: içerik, Content-Length, Content-Disposition', () async {
    await inRoot('şöğüİı rapor.txt').writeAsString('merhaba');
    final res = await f.send(
      'GET',
      '/api/download/${Uri.encodeComponent('şöğüİı rapor.txt')}',
    );
    expect(res.statusCode, 200);
    expect(res.headers['content-length'], '7');
    expect(
      res.headers['content-disposition'],
      "attachment; filename*=UTF-8''${Uri.encodeComponent('şöğüİı rapor.txt')}",
    );
    expect(await res.readAsString(), 'merhaba');
  });

  test('DELETE → 204 + olay, tekrar → 404', () async {
    await inRoot('sil.txt').writeAsString('x');
    final res = await f.send('DELETE', '/api/files/sil.txt');
    expect(res.statusCode, 204);
    expect(inRoot('sil.txt').existsSync(), isFalse);
    expect(f.events.single, isA<FileDeleted>());
    expect((await f.send('DELETE', '/api/files/sil.txt')).statusCode, 404);
  });

  test('upload: kaydeder, olay yayınlar, aynı ad → (1)', () async {
    for (var i = 0; i < 2; i++) {
      final res = await f.send(
        'POST',
        '/api/upload',
        headers: multipartHeaders,
        body: multipartBody('not.txt', 'icerik$i'.codeUnits),
      );
      expect(res.statusCode, 200);
    }
    expect(await inRoot('not.txt').readAsString(), 'icerik0');
    expect(await inRoot('not (1).txt').readAsString(), 'icerik1');
    expect(f.events.whereType<FileUploaded>().map((e) => e.name), [
      'not.txt',
      'not (1).txt',
    ]);
  });

  test('upload: zararlı ad temizlenir', () async {
    final res = await f.send(
      'POST',
      '/api/upload',
      headers: multipartHeaders,
      body: multipartBody('../../kotu.txt', 'x'.codeUnits),
    );
    expect(res.statusCode, 200);
    expect(f.dir.listSync().whereType<File>(), isEmpty);
    final names = f.storage.root.listSync().map((e) => e.uri.pathSegments.last);
    expect(names.single, isNot(contains('..')));
  });

  test('upload: akış sırasında limit aşımı → 413, .part yok', () async {
    // Content-Length yok → limit akış sırasında yakalanır.
    final res = await f.send(
      'POST',
      '/api/upload',
      headers: multipartHeaders,
      body: Stream.value(multipartBody('buyuk.bin', List.filled(4096, 7))),
    );
    expect(res.statusCode, 413);
    expect(f.storage.root.listSync(), isEmpty);
  });

  test('upload: Content-Length limit üstü → okumadan 413', () async {
    final res = await f.send(
      'POST',
      '/api/upload',
      headers: {...multipartHeaders, 'content-length': '999999'},
      body: Stream<List<int>>.error(StateError('okunmamalı')),
    );
    expect(res.statusCode, 413);
  });

  test('upload: multipart değil → 400', () async {
    final res = await f.send('POST', '/api/upload', body: 'duz metin');
    expect(res.statusCode, 400);
  });

  test('bilinmeyen route → 404 JSON', () async {
    final res = await f.send('GET', '/api/yok');
    expect(res.statusCode, 404);
    expect(await readJson(res), {'error': 'Bulunamadı'});
  });
}
