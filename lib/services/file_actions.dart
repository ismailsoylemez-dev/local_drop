import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../core/log.dart';

/// Seçilen dosya: ad + akışla okuma (RAM'e alınmaz).
typedef PickedFile = ({String name, Stream<List<int>> Function() read});

/// Platform eklentileri (aç, paylaş, seç). UI test edilebilsin diye ayrı.
class FileActions {
  const FileActions();

  /// Dosyayı ilgili uygulamayla açar; başarısızsa kullanıcıya gösterilecek
  /// Türkçe mesaj, başarılıysa null döner.
  Future<String?> open(String path) async {
    final result = await OpenFilex.open(path);
    Log.d('Files', 'open ${result.type}: ${result.message}');
    return switch (result.type) {
      ResultType.done => null,
      ResultType.noAppToOpen => 'Bu dosyayı açacak uygulama yok',
      ResultType.fileNotFound => 'Dosya bulunamadı',
      ResultType.permissionDenied => 'Dosyayı açma izni yok',
      ResultType.error => 'Dosya açılamadı',
    };
  }

  Future<void> share(String path) =>
      SharePlus.instance.share(ShareParams(files: [XFile(path)]));

  /// Çoklu seçim; iptal → boş liste.
  Future<List<PickedFile>> pick() async {
    final files = await FilePicker.pickFiles();
    return [for (final f in files) (name: f.name, read: f.readAsByteStream)];
  }
}
