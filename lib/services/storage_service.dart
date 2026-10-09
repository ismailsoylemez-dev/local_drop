import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/errors.dart';
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
}
