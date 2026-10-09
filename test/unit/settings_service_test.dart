import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_drop/services/settings_service.dart';
import 'package:local_drop/services/storage_target.dart';

void main() {
  late Directory tmp;
  late File file;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ld_settings_');
    file = File('${tmp.path}/alt/settings.json');
  });
  tearDown(() => tmp.delete(recursive: true));

  test('dosya yoksa varsayılan: uygulama klasörü', () async {
    final s = SettingsService(file);
    await s.load();
    expect(s.saveLocation, SaveLocation.appFolder);
  });

  test('kaydet → yeni örnek aynı değeri okur', () async {
    await SettingsService(file).setSaveLocation(SaveLocation.downloads);
    final s = SettingsService(file);
    await s.load();
    expect(s.saveLocation, SaveLocation.downloads);
  });

  test('bozuk veya bilinmeyen değer → varsayılan', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{bozuk');
    final s = SettingsService(file);
    await s.load();
    expect(s.saveLocation, SaveLocation.appFolder);

    await file.writeAsString('{"saveLocation":"bulut"}');
    await s.load();
    expect(s.saveLocation, SaveLocation.appFolder);
  });
}
