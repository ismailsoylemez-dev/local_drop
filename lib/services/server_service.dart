import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/log.dart';
import '../core/secrets.dart';
import '../core/wakelock_policy.dart';
import '../server/router.dart';
import '../server/server_event.dart';
import 'storage_service.dart';
import 'storage_target.dart';

/// shelf sunucusunun yaşam döngüsü. Her [start]'ta yeni token + PIN.
class ServerService {
  ServerService({
    required this.storage,
    InternetAddress? address,
    this.portStart = AppConstants.portRangeStart,
    this.portEnd = AppConstants.portRangeEnd,
    this.maxFileBytes = AppConstants.maxFileBytes,
    this.transfers = const NoopTransferObserver(),
    this.target,
  }) : address = address ?? InternetAddress.anyIPv4;

  final StorageService storage;
  final InternetAddress address;
  final int portStart;
  final int portEnd;
  final int maxFileBytes;
  final TransferObserver transfers;
  final StorageTarget? target;

  final _events = StreamController<ServerEvent>.broadcast();
  HttpServer? _server;
  String? _token;
  String? _pin;

  Stream<ServerEvent> get events => _events.stream;
  bool get isRunning => _server != null;
  int? get port => _server?.port;
  String? get token => _token;
  String? get pin => _pin;

  /// Aralıktaki ilk boş portta açar; dinlenen portu döner.
  Future<int> start() async {
    if (_server case final server?) return server.port;
    await storage.ensureExists();
    final token = generateToken();
    final pin = generatePin();
    final handler = buildHandler(
      storage: storage,
      token: token,
      pin: pin,
      maxFileBytes: maxFileBytes,
      onEvent: _events.add,
      transfers: transfers,
      target: target,
    );

    for (var port = portStart; port <= portEnd; port++) {
      try {
        final server = await shelf_io.serve(handler, address, port);
        _server = server;
        _token = token;
        _pin = pin;
        Log.d(
          'Server',
          'started ${address.address}:${server.port} token=${Log.mask(token)}',
        );
        return server.port;
      } on SocketException catch (e) {
        Log.d('Server', 'port $port dolu: ${e.osError?.message}');
      }
    }
    throw const ServerStartException('Port bulunamadı');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _token = null;
    _pin = null;
    if (server == null) return;
    await server.close(force: true);
    Log.d('Server', 'stopped');
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}
