import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/server_service.dart';
import 'package:local_drop/services/storage_service.dart';

/// Ham HTTP isteği: yol, istemci (Uri) normalleştirmesi olmadan gider.
Future<(int, String)> rawRequest(
  int port,
  String requestLine, {
  Map<String, String> headers = const {},
  List<int> body = const [],
}) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  final head = StringBuffer(
    '$requestLine\r\nHost: 127.0.0.1\r\nConnection: close\r\n',
  );
  headers.forEach((k, v) => head.write('$k: $v\r\n'));
  if (body.isNotEmpty) head.write('Content-Length: ${body.length}\r\n');
  head.write('\r\n');
  socket
    ..add(latin1.encode(head.toString()))
    ..add(body);
  await socket.flush();
  final response = latin1.decode(
    await socket.fold<List<int>>([], (a, b) => a..addAll(b)),
  );
  socket.destroy();
  final status = int.parse(response.split(' ')[1]);
  final bodyStart = response.indexOf('\r\n\r\n');
  return (status, bodyStart < 0 ? '' : response.substring(bodyStart + 4));
}

void main() {
  late Directory tmp;
  late Directory root;
  late ServerService server;
  late int port;
  late String token;
  const secret = 'GIZLI-ICERIK';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_abuse_');
    root = Directory('${tmp.path}${Platform.pathSeparator}received');
    // Kök dışında okunmaması gereken dosyalar.
    await File('${tmp.path}${Platform.pathSeparator}secret')
        .writeAsString(secret);
    await File('${tmp.path}${Platform.pathSeparator}a.txt')
        .writeAsString(secret);
    server = ServerService(
      storage: StorageService(root),
      address: InternetAddress.loopbackIPv4,
      portStart: 0,
      portEnd: 0,
    );
    port = await server.start();
    token = server.token!;
  });

  tearDown(() async {
    await server.dispose();
    await tmp.delete(recursive: true);
  });

  /// Kök dışında (tmp altında) yeni dosya oluşmadı.
  void expectNothingOutsideRoot() {
    final outside = tmp
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(outside, {'secret', 'a.txt', 'received'});
  }

  for (final path in [
    '/api/download/%2e%2e%2fsecret',
    '/api/download/%2e%2e%2f%2e%2e%2fsecret',
    '/api/download/%2e%2e/secret',
    '/api/download/..%2fsecret',
    '/api/download/..%5csecret',
    '/api/download/%252e%252e%252fsecret',
    '/api/download/%2fdata%2flocal%2ftmp%2fsecret',
    '/api/download//etc/passwd',
    '/api/download/a%00.txt',
    '/api/download/..',
  ]) {
    test('GET $path → 400/404, kök dışı okunmaz', () async {
      final (status, body) = await rawRequest(
        port,
        'GET $path?t=$token HTTP/1.1',
      );
      expect([400, 404], contains(status), reason: path);
      expect(body, isNot(contains(secret)));
    });
  }

  for (final path in [
    '/api/files/%2e%2e%2fsecret',
    '/api/files/..%2fa.txt',
    '/api/files/a%00.txt',
  ]) {
    test('DELETE $path → 400/404, kök dışı silinmez', () async {
      final (status, _) = await rawRequest(
        port,
        'DELETE $path?t=$token HTTP/1.1',
      );
      expect([400, 404], contains(status), reason: path);
      expect(File('${tmp.path}/secret').existsSync(), isTrue);
      expect(File('${tmp.path}/a.txt').existsSync(), isTrue);
    });
  }

  for (final filename in [
    '../../kotu.txt',
    '..\\\\..\\\\kotu.txt',
    '%2e%2e%2fkotu.txt',
    '/data/local/tmp/kotu.txt',
    'C:\\\\Windows\\\\kotu.txt',
    'a\u0000.txt',
    '..',
  ]) {
    test('upload filename=${jsonEncode(filename)} → kök içinde kalır', () async {
      const boundary = 'abuseboundary';
      final body = [
        ...latin1.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n',
        ),
        ...utf8.encode('icerik'),
        ...latin1.encode('\r\n--$boundary--\r\n'),
      ];
      final (status, response) = await rawRequest(
        port,
        'POST /api/upload?t=$token HTTP/1.1',
        headers: {'Content-Type': 'multipart/form-data; boundary=$boundary'},
        body: body,
      );
      // NUL içeren başlığı multipart ayrıştırıcısı reddedebilir (400):
      // o durumda da hiçbir şey yazılmamalı.
      expect([200, 400], contains(status), reason: response);
      expectNothingOutsideRoot();
      final saved = root.listSync().whereType<File>().toList();
      if (status == 400) {
        expect(root.listSync(), isEmpty);
        return;
      }
      expect(saved, hasLength(1));
      final name = saved.single.uri.pathSegments.last;
      expect(name, isNot(contains('..')));
      expect(name, isNot(contains('\u0000')));
      expect(await saved.single.readAsString(), 'icerik');
    });
  }
}
