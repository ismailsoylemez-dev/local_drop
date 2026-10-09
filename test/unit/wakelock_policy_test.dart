import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/wakelock_policy.dart';

import '../server/handler_test_utils.dart';

class FakeLocks implements LockAdapter {
  final calls = <String>[];

  @override
  void acquire() => calls.add('acquire');

  @override
  void release() => calls.add('release');
}

void main() {
  late FakeLocks locks;
  late WakelockPolicy policy;

  setUp(() {
    locks = FakeLocks();
    policy = WakelockPolicy(locks);
  });

  test('0→1 acquire, 1→2 tek acquire, 2→0 release', () {
    policy.begin();
    expect(locks.calls, ['acquire']);
    policy.begin();
    expect(locks.calls, ['acquire']);
    expect(policy.active, 2);
    policy.end();
    expect(locks.calls, ['acquire']);
    policy.end();
    expect(locks.calls, ['acquire', 'release']);
    expect(policy.active, 0);
  });

  test('fazla end sayacı negatife düşürmez, tekrar release yok', () {
    policy
      ..begin()
      ..end()
      ..end();
    expect(policy.active, 0);
    expect(locks.calls, ['acquire', 'release']);
    policy.begin();
    expect(locks.calls, ['acquire', 'release', 'acquire']);
  });

  group('handler entegrasyonu', () {
    late HandlerFixture f;

    setUp(() async {
      f = await HandlerFixture.create(maxFileBytes: 1024, transfers: policy);
    });
    tearDown(() => f.dispose());

    test('başarılı upload → acquire + release', () async {
      final res = await f.send(
        'POST',
        '/api/upload',
        headers: multipartHeaders,
        body: multipartBody('a.txt', 'x'.codeUnits),
      );
      expect(res.statusCode, 200);
      expect(locks.calls, ['acquire', 'release']);
    });

    test('hatayla biten upload (413) de sayacı düşürür', () async {
      final res = await f.send(
        'POST',
        '/api/upload',
        headers: multipartHeaders,
        body: Stream.value(multipartBody('b.bin', List.filled(4096, 1))),
      );
      expect(res.statusCode, 413);
      expect(policy.active, 0);
      expect(locks.calls, ['acquire', 'release']);
    });

    test('download: akış bitince release', () async {
      await File('${f.storage.root.path}${Platform.pathSeparator}d.txt')
          .writeAsString('veri');
      final res = await f.send('GET', '/api/download/d.txt');
      expect(locks.calls, isEmpty, reason: 'akış dinlenmeden başlamaz');
      expect(await res.readAsString(), 'veri');
      expect(locks.calls, ['acquire', 'release']);
    });

    test('download: istemci koparsa (iptal) release', () async {
      await File('${f.storage.root.path}${Platform.pathSeparator}e.bin')
          .writeAsBytes(List.filled(1 << 20, 2));
      final res = await f.send('GET', '/api/download/e.bin');
      final sub = res.read().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(policy.active, 0);
      expect(locks.calls, ['acquire', 'release']);
    });
  });
}
