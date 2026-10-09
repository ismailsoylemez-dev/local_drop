import 'dart:io';

import 'package:shelf/shelf.dart';

import '../../core/errors.dart';
import '../../core/log.dart';
import '../../services/storage_service.dart';
import '../responses.dart';
import '../server_event.dart';

/// Liste, indirme ve silme.
class FilesHandler {
  FilesHandler({required this.storage, required this.onEvent});

  final StorageService storage;
  final void Function(ServerEvent) onEvent;

  Future<Response> list(Request request) async {
    final files = await storage.list();
    return jsonOk([
      for (final f in files)
        {
          'name': f.name,
          'size': f.size,
          'modified': f.modified.toUtc().toIso8601String(),
        },
    ]);
  }

  Future<Response> download(Request request, String rawName) async {
    final target = _resolve(rawName);
    if (target == null) return jsonError(HttpStatus.badRequest, 'Geçersiz ad');
    final (name, file) = target;
    if (!await file.exists()) {
      return jsonError(HttpStatus.notFound, 'Dosya bulunamadı');
    }
    final length = await file.length();
    Log.d('Download', 'name=$name bytes=$length');
    return Response.ok(
      file.openRead(),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/octet-stream',
        HttpHeaders.contentLengthHeader: '$length',
        'content-disposition':
            "attachment; filename*=UTF-8''${Uri.encodeComponent(name)}",
      },
    );
  }

  Future<Response> delete(Request request, String rawName) async {
    final target = _resolve(rawName);
    if (target == null) return jsonError(HttpStatus.badRequest, 'Geçersiz ad');
    final (name, file) = target;
    if (!await file.exists()) {
      return jsonError(HttpStatus.notFound, 'Dosya bulunamadı');
    }
    await file.delete();
    Log.d('Files', 'deleted name=$name');
    onEvent(FileDeleted(name));
    return Response(HttpStatus.noContent);
  }

  /// Ham (yüzde-kodlu) route parametresini çözer; güvenli değilse null.
  (String, File)? _resolve(String rawName) {
    try {
      final name = Uri.decodeComponent(rawName);
      return (name, storage.resolve(name, strict: true));
    } on ArgumentError {
      return null;
    } on PathEscapeException {
      return null;
    }
  }
}
