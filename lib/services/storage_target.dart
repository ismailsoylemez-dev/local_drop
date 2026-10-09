import 'dart:io';

import '../core/log.dart';

/// Alınan dosyaların son yeri.
enum SaveLocation { appFolder, downloads }

/// MediaStore köprüsü (Android'de native; testte sahte).
abstract interface class MediaStoreAdapter {
  /// Android 10+ (MediaStore.Downloads).
  Future<bool> isSupported();

  /// [source]'u `Download/<klasör>/<name>` olarak kopyalar.
  Future<void> saveToDownloads(File source, String name);
}

/// Biten dosyayı ayara göre yerinde bırakır ya da İndirilenler'e taşır.
/// `.part` buraya hiç gelmez: yalnız rename edilmiş, tamamlanmış dosya.
class StorageTarget {
  StorageTarget({required this.adapter, required this.location});

  final MediaStoreAdapter adapter;
  final SaveLocation Function() location;

  /// Taşındıysa true. Taşıma hatasında dosya uygulama klasöründe kalır ve
  /// istisna yukarı iletilir (handler `ServerErrorEvent` yayınlar).
  Future<bool> finalize(File file, String name) async {
    if (location() != SaveLocation.downloads) return false;
    await adapter.saveToDownloads(file, name);
    try {
      await file.delete();
    } catch (e) {
      // Kopya İndirilenler'de; yerel kopya silinemezse yalnız loglanır.
      Log.d('Storage', 'taşındı ama yerel silinemedi name=$name: $e');
    }
    Log.d('Storage', 'downloads name=$name');
    return true;
  }
}
