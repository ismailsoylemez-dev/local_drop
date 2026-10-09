import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/log.dart';
import '../core/safe_name.dart';

typedef StoredFile = ({String name, int size, DateTime modified});

/// Alınan dosyaların kök klasörü. Tüm yollar [resolve] üzerinden kurulur.
/// [exportDir] (Android 11+: `Download/LocalDrop`) İndirilenler'e taşınan
/// dosyaları listede tutmak için okunur; yazma yalnız MediaStore ile yapılır.
class StorageService {
  StorageService(this.root, {this.exportDir});

  final Directory root;
  Directory? exportDir;

  /// Yüklemesi süren (henüz rename edilmemiş) adlar; eşzamanlı aynı ad için.
  final Set<String> _reserved = {};

  static Future<StorageService> appDefault() async {
    final docs = await getApplicationDocumentsDirectory();
    return StorageService(
      Directory(
        '${docs.path}${Platform.pathSeparator}${AppConstants.receivedDirName}',
      ),
    );
  }

  Future<void> ensureExists() => root.create(recursive: true);

  /// [name] için kök altındaki dosya. [strict] ise ad zaten güvenli olmalı
  /// (indirme/silme: `../x` gibi adlar düzeltilmez, reddedilir).
  File resolve(String name, {bool strict = false}) {
    final safe = safeName(name);
    if (strict && safe != name) throw PathEscapeException(name);
    final file = File('${root.path}${Platform.pathSeparator}$safe');
    if (file.absolute.parent.path != root.absolute.path) {
      throw PathEscapeException(name);
    }
    return file;
  }

  /// Var olan dosya: önce kök, yoksa [exportDir]. Yazma için [resolve].
  File resolveExisting(String name) {
    final file = resolve(name, strict: true);
    final export = _exportFile(file.uri.pathSegments.last);
    if (export != null && !file.existsSync() && export.existsSync()) {
      return export;
    }
    return file;
  }

  File? _exportFile(String safe) {
    final dir = exportDir;
    if (dir == null) return null;
    final file = File('${dir.path}${Platform.pathSeparator}$safe');
    if (file.absolute.parent.path != dir.absolute.path) {
      throw PathEscapeException(safe);
    }
    return file;
  }

  /// Yükleme sırasında kullanılan geçici dosya: `.<ad>.part` (güvenli adlar
  /// noktayla başlamadığından gerçek dosyalarla çakışmaz).
  File partFileFor(String safe) => File(
    '${root.path}${Platform.pathSeparator}.$safe${AppConstants.partExtension}',
  );

  /// Var olan ve rezerve edilmiş adlarla çakışmayan bir ad ayırır.
  String reserveUnique(String name) {
    final unique = uniqueName(
      safeName(name),
      (n) =>
          _reserved.contains(n) ||
          resolve(n).existsSync() ||
          (_exportFile(n)?.existsSync() ?? false),
    );
    _reserved.add(unique);
    return unique;
  }

  void release(String name) => _reserved.remove(name);

  bool _isPart(String name) =>
      name.startsWith('.') && name.endsWith(AppConstants.partExtension);

  /// Kök + [exportDir]'deki tamamlanmış dosyalar, ada göre sıralı. Aynı ad
  /// ikisinde de varsa kökteki gösterilir ([resolveExisting] ile aynı).
  Future<List<StoredFile>> list() async {
    final byName = <String, StoredFile>{};
    for (final dir in [?exportDir, root]) {
      try {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          if (_isPart(name) || safeName(name) != name) continue;
          final stat = await entity.stat();
          byName[name] = (name: name, size: stat.size, modified: stat.modified);
        }
      } on FileSystemException catch (e) {
        // İndirilenler okunamazsa (izin/sürüm) uygulama klasörü yine listelenir.
        Log.d('Storage', 'liste okunamadı dir=${dir.path}: $e');
      }
    }
    return byName.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Akışı `.part`'a yazar, bitince benzersiz adla rename eder. Hata, iptal
  /// veya [maxBytes] aşımında ([FileTooLargeException]) `.part` silinir.
  Future<({String name, int bytes})> saveStream(
    String name,
    Stream<List<int>> data, {
    int? maxBytes,
  }) async {
    await ensureExists();
    final unique = reserveUnique(name);
    final part = partFileFor(unique);
    var bytes = 0;
    try {
      await writePart(
        part,
        data.map((chunk) {
          bytes += chunk.length;
          if (maxBytes != null && bytes > maxBytes) {
            throw FileTooLargeException(maxBytes);
          }
          return chunk;
        }),
      );
      await part.rename(resolve(unique).path);
    } catch (e) {
      if (isDiskFull(e)) Log.d('Storage', 'disk dolu name=$unique');
      await _deletePart(part);
      rethrow;
    } finally {
      release(unique);
    }
    return (name: unique, bytes: bytes);
  }

  /// Akışı [part]'a yazar ve kapatır. Testler disk hatası için ezer.
  Future<void> writePart(File part, Stream<List<int>> data) async {
    final sink = part.openWrite();
    try {
      await sink.addStream(data);
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _deletePart(File part) async {
    try {
      if (await part.exists()) await part.delete();
    } catch (e) {
      Log.d('Storage', '.part silinemedi: $e');
    }
  }

  /// Güvenli adla kökteki (yoksa İndirilenler'deki) dosyayı siler; yoksa false.
  Future<bool> delete(String name) async {
    final file = resolveExisting(name);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}
