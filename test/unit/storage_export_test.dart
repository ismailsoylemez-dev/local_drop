import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/storage_service.dart';

void main() {
  late Directory tmp;
  late StorageService storage;
  late Directory export;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_export_');
    export = Directory('${tmp.path}/Download/LocalDrop')
      ..createSync(recursive: true);
    storage = StorageService(Directory('${tmp.path}/received'))
      ..exportDir = export;
    await storage.ensureExists();
  });
  tearDown(() => tmp.delete(recursive: true));

  test('liste İndirilenler + uygulama klasörünü birleştirir', () async {
    File('${export.path}/pc.pdf').writeAsStringSync('pc');
    storage.resolve('tel.txt').writeAsStringSync('tel');
    File('${export.path}/.yarim.part').writeAsStringSync('x');

    final names = (await storage.list()).map((f) => f.name);
    expect(names, ['pc.pdf', 'tel.txt']);
  });

  test('resolveExisting / delete İndirilenler\'deki dosyayı bulur', () async {
    File('${export.path}/pc.pdf').writeAsStringSync('pc');
    expect(storage.resolveExisting('pc.pdf').readAsStringSync(), 'pc');
    expect(await storage.delete('pc.pdf'), isTrue);
    expect(File('${export.path}/pc.pdf').existsSync(), isFalse);
    expect(await storage.delete('pc.pdf'), isFalse);
  });

  test('aynı ad İndirilenler\'de varsa yeni ad ayrılır', () {
    File('${export.path}/a.txt').writeAsStringSync('1');
    expect(storage.reserveUnique('a.txt'), 'a (1).txt');
  });

  test('kök dışına çıkan ad İndirilenler\'de de reddedilir', () {
    expect(() => storage.resolveExisting('../x.txt'), throwsA(anything));
  });

  test('İndirilenler klasörü yoksa yalnız uygulama klasörü', () async {
    await export.delete(recursive: true);
    storage.resolve('tel.txt').writeAsStringSync('tel');
    expect((await storage.list()).map((f) => f.name), ['tel.txt']);
  });
}
