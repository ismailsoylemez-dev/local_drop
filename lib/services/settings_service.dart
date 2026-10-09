import 'dart:convert';
import 'dart:io';

import '../core/log.dart';
import 'storage_target.dart';

/// Basit kalıcı ayarlar: uygulama belgelerindeki JSON dosyası.
/// (SharedPreferences F8'de eklenecek; o zamana kadar paket eklenmez.)
class SettingsService {
  SettingsService(this.file);

  final File file;
  SaveLocation _saveLocation = SaveLocation.appFolder;

  SaveLocation get saveLocation => _saveLocation;

  Future<void> load() async {
    try {
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json case {'saveLocation': final String value}) {
        _saveLocation = SaveLocation.values.firstWhere(
          (l) => l.name == value,
          orElse: () => SaveLocation.appFolder,
        );
      }
    } catch (e) {
      Log.d('Settings', 'okunamadı, varsayılan: $e');
    }
  }

  Future<void> setSaveLocation(SaveLocation value) async {
    _saveLocation = value;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'saveLocation': value.name}));
  }
}
