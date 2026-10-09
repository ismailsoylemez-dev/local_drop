import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/constants.dart';
import '../core/log.dart';
import '../core/wakelock_policy.dart';
import '../services/storage_service.dart';
import '../services/storage_target.dart';
import 'auth_middleware.dart';
import 'handlers/files_handler.dart';
import 'handlers/login_handler.dart';
import 'handlers/text_handler.dart';
import 'rate_limiter.dart';
import 'handlers/upload_handler.dart';
import 'responses.dart';
import 'server_event.dart';
import 'web_ui.dart';

const contentSecurityPolicy =
    "default-src 'self'; style-src 'self' 'unsafe-inline'; "
    "script-src 'self' 'unsafe-inline'";

/// Her yanıta CSP + nosniff.
Middleware securityHeaders() {
  return (inner) => (request) async {
    final response = await inner(request);
    return response.change(
      headers: {
        'content-security-policy': contentSecurityPolicy,
        'x-content-type-options': 'nosniff',
      },
    );
  };
}

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

/// Tüm sunucu: güvenlik başlıkları → hata → auth → route'lar.
Handler buildHandler({
  required StorageService storage,
  required String token,
  required String pin,
  required void Function(ServerEvent) onEvent,
  int maxFileBytes = AppConstants.maxFileBytes,
  TransferObserver transfers = const NoopTransferObserver(),
  StorageTarget? target,
  RateLimiter? limiter,
}) {
  final rateLimiter = limiter ?? RateLimiter();
  final files = FilesHandler(
    storage: storage,
    onEvent: onEvent,
    transfers: transfers,
  );
  final upload = UploadHandler(
    storage: storage,
    maxFileBytes: maxFileBytes,
    onEvent: onEvent,
    transfers: transfers,
    target: target,
  );
  final login = LoginHandler(pin: pin, token: token, limiter: rateLimiter);
  final text = TextHandler(onEvent: onEvent);

  final router =
      Router(
          notFoundHandler: (_) => jsonError(HttpStatus.notFound, 'Bulunamadı'),
        )
        ..get('/', (Request _) => Response.ok(webUiHtml, headers: htmlHeaders))
        ..get('/login', login.page)
        ..post('/login', login.submit)
        ..get('/api/files', files.list)
        ..post('/api/upload', upload.call)
        ..get('/api/download/<name>', files.download)
        ..delete('/api/files/<name>', files.delete)
        ..post('/api/text', text.call);

  return const Pipeline()
      .addMiddleware(securityHeaders())
      .addMiddleware(errorMiddleware())
      .addMiddleware(authMiddleware(token: token, limiter: rateLimiter))
      .addHandler(router.call);
}
