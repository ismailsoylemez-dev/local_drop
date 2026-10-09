import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/core/errors.dart';
import 'package:local_drop/server/router.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:shelf/shelf.dart';

import 'handler_test_utils.dart';

const _enospc = OSError('No space left on device', 28);

/// Bir miktar yazıp ENOSPC fırlatan depolama.
class FullStorage extends StorageService {
  FullStorage(super.root);

  @override
  Future<void> writePart(File part, Stream<List<int>> data) async {
    final sink = part.openWrite();
    await for (final chunk in data) {
      sink.add(chunk);
      await sink.flush();
      await sink.close();
      throw FileSystemException('Yazılamadı', part.path, _enospc);
    }
  }
}

void main() {
  late Directory tmp;
  late FullStorage storage;
  late Handler handler;
  final events = <ServerEvent>[];

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_full_');
    storage = FullStorage(Directory('${tmp.path}/r'));
    await storage.ensureExists();
    events.clear();
    handler = buildHandler(
      storage: storage,
      token: testToken,
      pin: testPin,
      onEvent: events.add,
    );
  });
  tearDown(() => tmp.delete(recursive: true));

  test('ENOSPC → 507 "Telefonda yer yok", .part yok, olay yok', () async {
    final res = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/upload?t=$testToken'),
        headers: multipartHeaders,
        body: multipartBody('buyuk.bin', List.filled(2048, 1)),
      ),
    );
    expect(res.statusCode, 507);
    expect(await readJson(res), {'error': 'Telefonda yer yok'});
    expect(storage.root.listSync(), isEmpty);
    expect(events, isEmpty);
  });

  test('saveStream ENOSPC fırlatır ve .part siler', () async {
    await expectLater(
      storage.saveStream('a.bin', Stream.value([1, 2, 3])),
      throwsA(predicate(isDiskFull)),
    );
    expect(storage.root.listSync(), isEmpty);
  });

  test('isDiskFull: ENOSPC ve Windows kodları; diğerleri değil', () {
    expect(isDiskFull(const FileSystemException('x', 'p', _enospc)), isTrue);
    expect(
      isDiskFull(const FileSystemException('x', 'p', OSError('full', 112))),
      isTrue,
    );
    expect(
      isDiskFull(const FileSystemException('x', 'p', OSError('denied', 13))),
      isFalse,
    );
    expect(isDiskFull(const FileSystemException('x')), isFalse);
    expect(isDiskFull(StateError('x')), isFalse);
  });

  test('disk dolu dışındaki dosya hatası → 500 (ayrıntı loga)', () async {
    final denied = _DeniedStorage(Directory('${tmp.path}/d'));
    await denied.ensureExists();
    final h = buildHandler(
      storage: denied,
      token: testToken,
      pin: testPin,
      onEvent: events.add,
    );
    final res = await h(
      Request(
        'POST',
        Uri.parse('http://localhost/api/upload?t=$testToken'),
        headers: multipartHeaders,
        body: multipartBody('a.bin', [1]),
      ),
    );
    expect(res.statusCode, 500);
    expect(denied.root.listSync(), isEmpty);
  });
}

class _DeniedStorage extends StorageService {
  _DeniedStorage(super.root);

  @override
  Future<void> writePart(File part, Stream<List<int>> data) async {
    await data.drain<void>();
    throw FileSystemException(
      'İzin yok',
      part.path,
      const OSError('Permission denied', 13),
    );
  }
}
