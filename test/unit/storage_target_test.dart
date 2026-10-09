import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/storage_target.dart';

import '../server/handler_test_utils.dart';

class FakeMediaStore implements MediaStoreAdapter {
  final saved = <String, List<int>>{};
  final seenPaths = <String>[];
  bool fail = false;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> saveToDownloads(File source, String name) async {
    seenPaths.add(source.path);
    if (fail) throw const FileSystemException('MediaStore dolu');
    saved[name] = await source.readAsBytes();
  }
}

void main() {
  late FakeMediaStore media;
  late SaveLocation location;
  late HandlerFixture f;

  setUp(() async {
    media = FakeMediaStore();
    location = SaveLocation.downloads;
    f = await HandlerFixture.create(
      maxFileBytes: 1024,
      target: StorageTarget(adapter: media, location: () => location),
    );
  });
  tearDown(() => f.dispose());

  Future<int> upload(
    String name,
    List<int> content, {
    bool stream = false,
  }) async {
    final body = multipartBody(name, content);
    final res = await f.send(
      'POST',
      '/api/upload',
      headers: multipartHeaders,
      body: stream ? Stream.value(body) : body,
    );
    return res.statusCode;
  }

  List<String> rootNames() =>
      f.storage.root.listSync().map((e) => e.uri.pathSegments.last).toList();

  test(
    'İndirilenler: biten dosya taşınır, uygulama klasöründe kalmaz',
    () async {
      expect(await upload('rapor.pdf', [1, 2, 3]), 200);
      expect(media.saved, {
        'rapor.pdf': [1, 2, 3],
      });
      expect(rootNames(), isEmpty);
      expect(f.events.whereType<FileUploaded>().single.name, 'rapor.pdf');
    },
  );

  test('.part hiç taşınmaz', () async {
    await upload('a.txt', [1]);
    // Limit aşımı: akış yarıda kesilir, .part oluşmuştu.
    expect(await upload('b.bin', List.filled(4096, 1), stream: true), 413);
    expect(media.seenPaths, hasLength(1));
    expect(media.seenPaths.single, isNot(endsWith('.part')));
    expect(media.saved.keys, ['a.txt']);
  });

  test('Uygulama klasörü seçiliyse taşınmaz', () async {
    location = SaveLocation.appFolder;
    expect(await upload('kal.txt', [9]), 200);
    expect(media.seenPaths, isEmpty);
    expect(rootNames(), ['kal.txt']);
  });

  test(
    'taşıma hatası → dosya uygulama klasöründe kalır + error olayı',
    () async {
      media.fail = true;
      expect(await upload('kal.txt', [7, 7]), 200);
      expect(rootNames(), ['kal.txt']);
      expect(
        await File('${f.storage.root.path}${Platform.pathSeparator}kal.txt')
            .readAsBytes(),
        [7, 7],
      );
      final error = f.events.whereType<ServerErrorEvent>().single;
      expect(error.message, contains('kal.txt'));
      expect(f.events.whereType<FileUploaded>(), hasLength(1));
    },
  );
}
