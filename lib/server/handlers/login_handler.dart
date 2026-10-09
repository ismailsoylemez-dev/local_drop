import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../core/constants.dart';
import '../../core/log.dart';
import '../../core/secrets.dart';
import '../auth_middleware.dart';
import '../rate_limiter.dart';
import '../responses.dart';

String _page({String? error}) =>
    '''<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Local Drop — Giriş</title></head>
<body style="font-family:sans-serif;max-width:320px;margin:48px auto;padding:0 16px">
<h1>Local Drop</h1>
<p>Telefon ekranındaki PIN'i girin.</p>
${error == null ? '' : '<p style="color:#b00020">$error</p>'}
<form method="post" action="/login">
<input name="pin" inputmode="numeric" autocomplete="off" maxlength="${AppConstants.pinLength}" autofocus>
<button type="submit">Giriş</button>
</form></body></html>''';

/// PIN ile cookie alma. PIN doğruysa token cookie'si set edilip `/`'a yönlenir.
class LoginHandler {
  LoginHandler({required this.pin, required this.token, required this.limiter});

  final String pin;
  final String token;

  /// Engel kontrolü auth ara katmanında; burada yalnız sayılır/sıfırlanır.
  final RateLimiter limiter;

  Response page(Request request) => Response.ok(_page(), headers: htmlHeaders);

  Future<Response> submit(Request request) async {
    final length = request.contentLength;
    if (length == null || length > AppConstants.loginBodyMaxBytes) {
      return Response(
        HttpStatus.requestEntityTooLarge,
        body: _page(error: 'Geçersiz istek.'),
        headers: htmlHeaders,
      );
    }
    final body = await request.readAsString(utf8);
    final entered = Uri.splitQueryString(body)['pin'] ?? '';
    final ip = clientIp(request);
    if (!constantTimeEquals(entered, pin)) {
      limiter.recordFailure(ip);
      Log.d('Auth', 'login: yanlış PIN ip=$ip');
      return Response(
        HttpStatus.unauthorized,
        body: _page(error: 'PIN hatalı.'),
        headers: htmlHeaders,
      );
    }
    limiter.reset(ip);
    Log.d('Auth', 'login: PIN doğru');
    return Response.found(
      '/',
      headers: {HttpHeaders.setCookieHeader: tokenCookie(token)},
    );
  }
}
