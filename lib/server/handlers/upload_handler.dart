import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import '../../core/errors.dart';
import '../../core/log.dart';
import '../../services/storage_service.dart';
import '../responses.dart';
import '../server_event.dart';

/// İstek gövdesini izler. mime 2.1.0 gövde hatasını/erken bitişini yalnız dış
/// akışa iletir, okunmakta olan parçayı kapatmaz → yazma sonsuza dek bekler.
/// Bu yüzden kopma algılanınca aktif parça hatayla kapatılır.
class _BodyGuard {
  _BodyGuard(this.expectedBytes);

  final int? expectedBytes;
  int _received = 0;
  Object? _error;
  StreamController<List<int>>? _current;

  Stream<List<int>> wrap(Stream<List<int>> body) =>
      body.cast<List<int>>().transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            _received += data.length;
            sink.add(data);
          },
          handleError: (error, stack, sink) {
            _abort(error);
            sink.addError(error, stack);
          },
          handleDone: (sink) {
            final expected = expectedBytes;
            if (expected != null && _received < expected) {
              _abort(const HttpException('Bağlantı yükleme sırasında koptu'));
            }
            sink.close();
          },
        ),
      );

  /// Parça akışını, kopmada hatayla kapatılabilir bir akışa sarar.
  Stream<List<int>> track(Stream<List<int>> part) {
    late StreamSubscription<List<int>> sub;
    final controller = StreamController<List<int>>();
    controller
      ..onListen = () {
        sub = part.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            if (identical(_current, controller)) _current = null;
            controller.close();
          },
        );
      }
      ..onPause = (() => sub.pause())
      ..onResume = (() => sub.resume())
      ..onCancel = (() => sub.cancel());
    _current = controller;
    if (_error case final error?) _abort(error);
    return controller.stream;
  }

  void _abort(Object error) {
    _error = error;
    final current = _current;
    _current = null;
    if (current != null && !current.isClosed) {
      current
        ..addError(error)
        ..close();
    }
  }
}

/// `multipart/form-data` yükleme: her dosya akışla `.part`'a yazılır, bitince
/// rename edilir. Limit aşımı veya yarıda kalma → `.part` silinir.
class UploadHandler {
  UploadHandler({
    required this.storage,
    required this.maxFileBytes,
    required this.onEvent,
  });

  final StorageService storage;
  final int maxFileBytes;
  final void Function(ServerEvent) onEvent;

  Future<Response> call(Request request) async {
    final length = request.contentLength;
    if (length != null && length > maxFileBytes) {
      Log.d('Upload', 'reject content-length=$length');
      return _tooLarge();
    }
    final guard = _BodyGuard(length);
    final form = FormDataRequest.of(
      request.change(body: guard.wrap(request.read())),
    );
    if (form == null) {
      return jsonError(HttpStatus.badRequest, 'multipart/form-data bekleniyor');
    }

    final saved = <String>[];
    try {
      await for (final data in form.formData) {
        final filename = data.filename;
        if (filename == null) {
          await guard.track(data.part).drain<void>();
          continue;
        }
        final file = await storage.saveStream(
          filename,
          guard.track(data.part),
          maxBytes: maxFileBytes,
        );
        Log.d('Upload', 'done name=${file.name} bytes=${file.bytes}');
        onEvent(FileUploaded(file.name, file.bytes));
        saved.add(file.name);
      }
    } on FileTooLargeException {
      return _tooLarge();
    } on FileSystemException {
      rethrow;
    } catch (e) {
      Log.d('Upload', 'aborted: $e');
      return jsonError(HttpStatus.badRequest, 'Yükleme yarıda kaldı');
    }
    return jsonOk({'files': saved});
  }

  Response _tooLarge() =>
      jsonError(HttpStatus.requestEntityTooLarge, 'Dosya çok büyük');
}
