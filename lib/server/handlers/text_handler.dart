import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import '../../core/constants.dart';
import '../../core/log.dart';
import '../responses.dart';
import '../server_event.dart';

class _TooLarge implements Exception {
  const _TooLarge();
}

/// `POST /api/text` — JSON `{text}`; ≤ [AppConstants.maxTextBytes].
class TextHandler {
  TextHandler({required this.onEvent});

  final void Function(ServerEvent) onEvent;

  Future<Response> call(Request request) async {
    final length = request.contentLength;
    if (length != null && length > AppConstants.maxTextBytes) {
      return _tooLarge();
    }

    final String body;
    try {
      body = await _readLimited(request.read());
    } on _TooLarge {
      return _tooLarge();
    } on FormatException {
      return jsonError(HttpStatus.badRequest, 'Geçersiz metin kodlaması');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return jsonError(HttpStatus.badRequest, 'JSON bekleniyor');
    }
    if (decoded case {'text': final String text} when text.isNotEmpty) {
      Log.d('Text', 'received chars=${text.length}');
      onEvent(TextReceived(text));
      return jsonOk({'ok': true});
    }
    return jsonError(HttpStatus.badRequest, '"text" alanı boş veya eksik');
  }

  Response _tooLarge() =>
      jsonError(HttpStatus.requestEntityTooLarge, 'Metin çok uzun');

  Future<String> _readLimited(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
      if (bytes.length > AppConstants.maxTextBytes) throw const _TooLarge();
    }
    return utf8.decode(bytes.takeBytes());
  }
}
