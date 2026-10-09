import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/log.dart';
import '../core/safe_name.dart';

typedef StoredFile = ({String name, int size, DateTime modified});

/// Alınan dosyaların kök klasörü. Tüm yollar [resolve] üzerinden kurulur.
class StorageService {
  StorageService(this.root);

  final Directory root;

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

  /// Yükleme sırasında kullanılan geçici dosya: `.<ad>.part` (güvenli adlar
  /// noktayla başlamadığından gerçek dosyalarla çakışmaz).
  File partFileFor(String safe) => File(
    '${root.path}${Platform.pathSeparator}.$safe${AppConstants.partExtension}',
  );

  /// Var olan ve rezerve edilmiş adlarla çakışmayan bir ad ayırır.
  String reserveUnique(String name) {
    final unique = uniqueName(
      safeName(name),
      (n) => _reserved.contains(n) || resolve(n).existsSync(),
    );
    _reserved.add(unique);
    return unique;
  }

  void release(String name) => _reserved.remove(name);

  bool _isPart(String name) =>
      name.startsWith('.') && name.endsWith(AppConstants.partExtension);

  /// Kökteki tamamlanmış dosyalar, ada göre sıralı.
  Future<List<StoredFile>> list() async {
    if (!await root.exists()) return [];
    final result = <StoredFile>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (_isPart(name)) continue;
      final stat = await entity.stat();
      result.add((name: name, size: stat.size, modified: stat.modified));
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
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
    final sink = part.openWrite();
    var bytes = 0;
    try {
      await sink.addStream(
        data.map((chunk) {
          bytes += chunk.length;
          if (maxBytes != null && bytes > maxBytes) {
            throw FileTooLargeException(maxBytes);
          }
          return chunk;
        }),
      );
      await sink.close();
      await part.rename(resolve(unique).path);
    } catch (_) {
      await _discard(sink, part);
      rethrow;
    } finally {
      release(unique);
    }
    return (name: unique, bytes: bytes);
  }

  Future<void> _discard(IOSink sink, File part) async {
    try {
      await sink.close();
    } catch (_) {}
    try {
      if (await part.exists()) await part.delete();
    } catch (e) {
      Log.d('Storage', '.part silinemedi: $e');
    }
  }

  /// Güvenli adla kökteki dosyayı siler; yoksa false.
  Future<bool> delete(String name) async {
    final file = resolve(name, strict: true);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }
}
