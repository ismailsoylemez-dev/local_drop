import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/rate_limiter.dart';

import '../server/handler_test_utils.dart';

void main() {
  late DateTime now;
  late RateLimiter limiter;

  setUp(() {
    now = DateTime(2026, 10, 9, 12);
    limiter = RateLimiter(now: () => now);
  });

  group('RateLimiter (saf)', () {
    test('10 hata → engel; pencere dolunca açılır', () {
      for (var i = 0; i < 9; i++) {
        limiter.recordFailure('a');
      }
      expect(limiter.retryAfter('a'), isNull);
      limiter.recordFailure('a');
      expect(limiter.retryAfter('a'), const Duration(minutes: 1));

      now = now.add(const Duration(seconds: 59));
      expect(limiter.retryAfter('a'), const Duration(seconds: 1));
      now = now.add(const Duration(seconds: 1));
      expect(limiter.retryAfter('a'), isNull);
    });

    test('kayan pencere: eski hatalar düşer', () {
      for (var i = 0; i < 9; i++) {
        limiter.recordFailure('a');
      }
      now = now.add(const Duration(seconds: 61));
      limiter.recordFailure('a');
      expect(limiter.retryAfter('a'), isNull);
    });

    test('reset sayacı sıfırlar; farklı IP bağımsız', () {
      for (var i = 0; i < 10; i++) {
        limiter.recordFailure('a');
      }
      expect(limiter.retryAfter('b'), isNull);
      limiter.reset('a');
      expect(limiter.retryAfter('a'), isNull);
    });

    test('retryAfterSeconds yukarı yuvarlar, en az 1', () {
      expect(retryAfterSeconds(const Duration(milliseconds: 1500)), 2);
      expect(retryAfterSeconds(Duration.zero), 1);
      expect(retryAfterSeconds(const Duration(seconds: 60)), 60);
    });
  });

  group('auth ile', () {
    late HandlerFixture f;

    setUp(() async => f = await HandlerFixture.create(limiter: limiter));
    tearDown(() => f.dispose());

    Future<int> wrong(String ip) async => (await f.send(
      'GET',
      '/api/files?t=yanlis',
      auth: false,
      ip: ip,
    )).statusCode;

    test(
      '10 yanlış → 11.si 429 + Retry-After; 60 sn sonra tekrar 401',
      () async {
        for (var i = 0; i < 10; i++) {
          expect(await wrong('10.0.0.2'), 401);
        }
        final blocked = await f.send(
          'GET',
          '/api/files?t=yanlis',
          auth: false,
          ip: '10.0.0.2',
        );
        expect(blocked.statusCode, 429);
        expect(blocked.headers['retry-after'], '60');

        now = now.add(const Duration(seconds: 60));
        expect(await wrong('10.0.0.2'), 401);
      },
    );

    test('engelli IP doğru token ile de 429; farklı IP etkilenmez', () async {
      for (var i = 0; i < 10; i++) {
        await wrong('10.0.0.2');
      }
      expect(
        (await f.send('GET', '/api/files', ip: '10.0.0.2')).statusCode,
        429,
      );
      expect(
        (await f.send('GET', '/api/files', ip: '10.0.0.3')).statusCode,
        200,
      );
      expect(await wrong('10.0.0.3'), 401);
    });

    test('doğru token sayacı sıfırlar', () async {
      for (var i = 0; i < 9; i++) {
        await wrong('10.0.0.2');
      }
      expect(
        (await f.send('GET', '/api/files', ip: '10.0.0.2')).statusCode,
        200,
      );
      for (var i = 0; i < 9; i++) {
        expect(await wrong('10.0.0.2'), 401);
      }
    });

    test('yanlış PIN de sayılır; engelde /login 429', () async {
      Future<int> login(String pin) async => (await f.send(
        'POST',
        '/login',
        auth: false,
        ip: '10.0.0.4',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'pin=$pin',
      )).statusCode;

      for (var i = 0; i < 10; i++) {
        expect(await login('000000'), 401);
      }
      expect(await login(testPin), 429);
    });

    test('kimliksiz GET / yönlendirmesi hata sayılmaz', () async {
      for (var i = 0; i < 15; i++) {
        final res = await f.send('GET', '/', auth: false, ip: '10.0.0.5');
        expect(res.statusCode, 302);
      }
    });
  });
}
