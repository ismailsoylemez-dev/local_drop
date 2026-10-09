import 'dart:io';

import 'package:shelf/shelf.dart';

import '../core/constants.dart';
import '../core/secrets.dart';
import 'responses.dart';

/// HttpOnly + SameSite=Strict token cookie'si.
String tokenCookie(String token) =>
    '${AppConstants.tokenCookieName}=$token; Path=/; HttpOnly; SameSite=Strict';

String? readCookie(Request request, String name) {
  final header = request.headers[HttpHeaders.cookieHeader];
  if (header == null) return null;
  for (final pair in header.split(';')) {
    final eq = pair.indexOf('=');
    if (eq < 0) continue;
    if (pair.substring(0, eq).trim() == name) {
      return pair.substring(eq + 1).trim();
    }
  }
  return null;
}

/// `/login` dışındaki her istek `?t=` veya `ld_token` cookie'si ister.
/// Geçerli `?t=` ile gelen istekte cookie set edilir.
Middleware authMiddleware({required String token}) {
  return (inner) => (request) async {
    final path = request.url.path;
    if (path == 'login') return inner(request);

    final query = request.url.queryParameters[AppConstants.tokenQueryParam];
    if (query != null && constantTimeEquals(query, token)) {
      final response = await inner(request);
      return response.change(
        headers: {HttpHeaders.setCookieHeader: tokenCookie(token)},
      );
    }

    final cookie = readCookie(request, AppConstants.tokenCookieName);
    if (cookie != null && constantTimeEquals(cookie, token)) {
      return inner(request);
    }

    if (path.isEmpty && request.method == 'GET') {
      return Response.found('/login');
    }
    return jsonError(HttpStatus.unauthorized, 'Yetkisiz');
  };
}
