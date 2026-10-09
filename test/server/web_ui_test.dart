import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/router.dart';
import 'package:local_drop/server/web_ui.dart';

import 'handler_test_utils.dart';

void main() {
  late HandlerFixture f;

  setUp(() async => f = await HandlerFixture.create());
  tearDown(() => f.dispose());

  test('GET / → 200, html, CSP + nosniff', () async {
    final res = await f.send('GET', '/');
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], 'text/html; charset=utf-8');
    expect(res.headers['content-security-policy'], contentSecurityPolicy);
    expect(
      contentSecurityPolicy,
      "default-src 'self'; style-src 'self' 'unsafe-inline'; "
      "script-src 'self' 'unsafe-inline'",
    );
    expect(res.headers['x-content-type-options'], 'nosniff');
    expect(await res.readAsString(), webUiHtml);
  });

  test('API ve hata yanıtlarında da güvenlik başlıkları var', () async {
    final ok = await f.send('GET', '/api/files');
    final unauthorized = await f.send('GET', '/api/files', auth: false);
    for (final res in [ok, unauthorized]) {
      expect(res.headers['content-security-policy'], contentSecurityPolicy);
      expect(res.headers['x-content-type-options'], 'nosniff');
    }
  });

  test('harici kaynak yok', () {
    expect(RegExp(r'https?://').hasMatch(webUiHtml), isFalse);
    expect(RegExp(r'''(src|href)\s*=\s*["']//''').hasMatch(webUiHtml), isFalse);
    expect(webUiHtml, isNot(contains('@import')));
  });

  test('innerHTML kullanılmıyor (kullanıcı verisi textContent ile)', () {
    // Beklenen sayı sabit: arayüz hiç innerHTML kullanmaz.
    expect(RegExp('innerHTML').allMatches(webUiHtml).length, 0);
    expect(
      RegExp('outerHTML|insertAdjacentHTML|document\\.write')
          .hasMatch(webUiHtml),
      isFalse,
    );
    expect(webUiHtml, contains('textContent'));
  });

  test('sabitler arayüze gömülü', () {
    expect(webUiHtml, contains('const MAX_TEXT = 65536;'));
    expect(webUiHtml, contains('const REFRESH_MS = 5000;'));
  });
}
