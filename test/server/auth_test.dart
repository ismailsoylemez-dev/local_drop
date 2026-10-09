import 'package:flutter_test/flutter_test.dart';

import 'handler_test_utils.dart';

void main() {
  late HandlerFixture f;

  setUp(() async => f = await HandlerFixture.create());
  tearDown(() => f.dispose());

  test('token yok → 401', () async {
    final res = await f.send('GET', '/api/files', auth: false);
    expect(res.statusCode, 401);
    expect(await readJson(res), {'error': 'Yetkisiz'});
  });

  test('yanlış token → 401', () async {
    final res = await f.send('GET', '/api/files?t=yanlis', auth: false);
    expect(res.statusCode, 401);
  });

  test('doğru query → 200 + HttpOnly SameSite=Strict cookie', () async {
    final res = await f.send('GET', '/api/files');
    expect(res.statusCode, 200);
    final cookie = res.headers['set-cookie']!;
    expect(cookie, startsWith('ld_token=$testToken'));
    expect(cookie, contains('HttpOnly'));
    expect(cookie, contains('SameSite=Strict'));
  });

  test('cookie ile → 200', () async {
    final res = await f.send(
      'GET',
      '/api/files',
      auth: false,
      headers: {'cookie': 'diger=1; ld_token=$testToken'},
    );
    expect(res.statusCode, 200);
  });

  test('yanlış cookie → 401', () async {
    final res = await f.send(
      'GET',
      '/api/files',
      auth: false,
      headers: {'cookie': 'ld_token=yanlis'},
    );
    expect(res.statusCode, 401);
  });

  test('token yokken / → /login yönlendirmesi', () async {
    final res = await f.send('GET', '/', auth: false);
    expect(res.statusCode, 302);
    expect(res.headers['location'], '/login');
  });

  test('eski cookie ile / → /login + cookie silinir, hatalı sayılmaz', () async {
    for (var i = 0; i < 12; i++) {
      final res = await f.send(
        'GET',
        '/',
        auth: false,
        headers: {'cookie': 'ld_token=eskiOturum'},
      );
      expect(res.statusCode, 302);
      expect(res.headers['location'], '/login');
      expect(res.headers['set-cookie'], contains('Max-Age=0'));
    }
    final login = await f.send('GET', '/login', auth: false);
    expect(login.statusCode, 200);
  });

  test('eski ?t= ile / → /login', () async {
    final res = await f.send('GET', '/?t=eskiToken', auth: false);
    expect(res.statusCode, 302);
    expect(res.headers['location'], '/login');
  });

  test('GET /login token istemez', () async {
    final res = await f.send('GET', '/login', auth: false);
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], contains('text/html'));
  });

  test('POST /login doğru PIN → cookie + /', () async {
    final res = await f.send(
      'POST',
      '/login',
      auth: false,
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: 'pin=$testPin',
    );
    expect(res.statusCode, 302);
    expect(res.headers['location'], '/');
    expect(res.headers['set-cookie'], startsWith('ld_token=$testToken'));
  });

  test('POST /login yanlış PIN → 401, cookie yok', () async {
    final res = await f.send(
      'POST',
      '/login',
      auth: false,
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: 'pin=000000',
    );
    expect(res.statusCode, 401);
    expect(res.headers['set-cookie'], isNull);
  });
}
