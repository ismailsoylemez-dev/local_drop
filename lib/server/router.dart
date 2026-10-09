import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../services/storage_service.dart';
import 'auth_middleware.dart';
import 'handlers/files_handler.dart';
import 'handlers/login_handler.dart';
import 'handlers/upload_handler.dart';
import 'responses.dart';
import 'server_event.dart';

/// Yakalanmayan istisna → 500 JSON; ayrıntı yalnız loga.
Middleware errorMiddleware() {
  return (inner) => (request) async {
    try {
      return await inner(request);
    } on HijackException {
      rethrow;
    } catch (e, st) {
      Log.d('Server', 'hata ${request.method} /${request.url.path}: $e\n$st');
      return jsonError(HttpStatus.internalServerError, 'Sunucu hatası');
    }
  };
}

/// Tüm sunucu: hata → auth → route'lar.
Handler buildHandler({
  required StorageService storage,
  required String token,
  required String pin,
  required void Function(ServerEvent) onEvent,
  int maxFileBytes = AppConstants.maxFileBytes,
}) {
  final files = FilesHandler(storage: storage, onEvent: onEvent);
  final upload = UploadHandler(
    storage: storage,
    maxFileBytes: maxFileBytes,
    onEvent: onEvent,
  );
  final login = LoginHandler(pin: pin, token: token);

  final router =
      Router(
          notFoundHandler: (_) => jsonError(HttpStatus.notFound, 'Bulunamadı'),
        )
        // TODO(F4): web arayüzü.
        ..get(
          '/',
          (Request _) => Response.ok(
            '<!doctype html><h1>Local Drop</h1>',
            headers: htmlHeaders,
          ),
        )
        ..get('/login', login.page)
        ..post('/login', login.submit)
        ..get('/api/files', files.list)
        ..post('/api/upload', upload.call)
        ..get('/api/download/<name>', files.download)
        ..delete('/api/files/<name>', files.delete);

  return const Pipeline()
      .addMiddleware(errorMiddleware())
      .addMiddleware(authMiddleware(token: token))
      .addHandler(router.call);
}
