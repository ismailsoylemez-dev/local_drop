import 'dart:convert';
import 'dart:io';

import 'package:local_drop/core/wakelock_policy.dart';
import 'package:local_drop/server/rate_limiter.dart';
import 'package:local_drop/server/router.dart';
import 'package:local_drop/server/server_event.dart';
import 'package:local_drop/services/storage_service.dart';
import 'package:local_drop/services/storage_target.dart';
import 'package:shelf/shelf.dart';

const testToken = 'TestToken1234567';
const testPin = '123456';

/// Geçici kök klasörle kurulmuş handler (ağ açılmaz).
class HandlerFixture {
  HandlerFixture._(this.dir, this.storage, this.handler, this.events);

  final Directory dir;
  final StorageService storage;
  final Handler handler;
  final List<ServerEvent> events;

  static Future<HandlerFixture> create({
    int maxFileBytes = 1 << 20,
    TransferObserver transfers = const NoopTransferObserver(),
    StorageTarget? target,
    RateLimiter? limiter,
  }) async {
    final dir = await Directory.systemTemp.createTemp('ld_handler_');
    final root = Directory('${dir.path}${Platform.pathSeparator}received');
    final storage = StorageService(root);
    await storage.ensureExists();
    final events = <ServerEvent>[];
    final handler = buildHandler(
      storage: storage,
      token: testToken,
      pin: testPin,
      maxFileBytes: maxFileBytes,
      onEvent: events.add,
      transfers: transfers,
      target: target,
      limiter: limiter,
    );
    return HandlerFixture._(dir, storage, handler, events);
  }

  Future<Response> send(
    String method,
    String path, {
    bool auth = true,
    Map<String, String>? headers,
    Object? body,
    String? ip,
  }) async {
    final sep = path.contains('?') ? '&' : '?';
    final url = auth ? '$path${sep}t=$testToken' : path;
    return await handler(
      Request(
        method,
        Uri.parse('http://localhost$url'),
        headers: headers,
        body: body,
        context: {
          if (ip != null) 'shelf.io.connection_info': FakeConnectionInfo(ip),
        },
      ),
    );
  }

  Future<void> dispose() => dir.delete(recursive: true);
}

Future<Object?> readJson(Response response) async =>
    jsonDecode(await response.readAsString());

const boundary = 'ldtestboundary';

List<int> multipartBody(String filename, List<int> content) => [
  ...utf8.encode(
    '--$boundary\r\n'
    'Content-Disposition: form-data; name="file"; filename="$filename"\r\n'
    'Content-Type: application/octet-stream\r\n\r\n',
  ),
  ...content,
  ...utf8.encode('\r\n--$boundary--\r\n'),
];

const multipartHeaders = {
  'content-type': 'multipart/form-data; boundary=$boundary',
};

/// shelf_io'nun koyduğu bağlantı bilgisi (istemci IP'si için).
class FakeConnectionInfo implements HttpConnectionInfo {
  FakeConnectionInfo(String ip) : remoteAddress = InternetAddress(ip);

  @override
  final InternetAddress remoteAddress;
  @override
  int get remotePort => 50000;
  @override
  int get localPort => 8080;
}
