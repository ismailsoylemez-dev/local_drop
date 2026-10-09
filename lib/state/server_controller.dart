import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/log.dart';
import '../server/server_event.dart';
import '../services/network_service.dart';
import '../services/server_service.dart';
import '../services/storage_service.dart';

enum ServerStatus { stopped, starting, running, error }

typedef ServerFactory = Future<ServerService> Function();

Future<ServerService> _defaultServer() async =>
    ServerService(storage: await StorageService.appDefault());

/// UI'nin tek durum kaynağı.
class ServerController extends ChangeNotifier {
  ServerController({
    required NetworkService network,
    this.createServer = _defaultServer,
  }) {
    _networkSub = network.watch().listen((result) {
      _network = result;
      notifyListeners();
    });
  }

  final ServerFactory createServer;
  late final StreamSubscription<NetworkResult> _networkSub;
  final _events = StreamController<ServerEvent>.broadcast();

  ServerService? _server;
  StreamSubscription<ServerEvent>? _serverSub;
  ServerStatus _status = ServerStatus.stopped;
  String? _url;
  String? _pin;
  String? _errorMessage;
  NetworkResult? _network;

  ServerStatus get status => _status;
  String? get url => _url;
  String? get pin => _pin;
  String? get errorMessage => _errorMessage;
  Stream<ServerEvent> get events => _events.stream;

  /// null = henüz kontrol edilmedi.
  NetworkResult? get network => _network;
  bool get canStart =>
      _network is Connected &&
      (_status == ServerStatus.stopped || _status == ServerStatus.error);

  Future<void> start() async {
    final network = _network;
    if (network is! Connected || !canStart) return;
    _status = ServerStatus.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      final server = _server ??= await createServer();
      _serverSub ??= server.events.listen(_events.add);
      final port = await server.start();
      _url =
          'http://${network.ip}:$port/?${AppConstants.tokenQueryParam}=${server.token}';
      _pin = server.pin;
      _status = ServerStatus.running;
    } on ServerStartException catch (e) {
      _fail(e.message, e);
    } catch (e) {
      _fail('Sunucu başlatılamadı', e);
    }
    notifyListeners();
  }

  void _fail(String message, Object error) {
    Log.d('Server', 'start hata: $error');
    _status = ServerStatus.error;
    _errorMessage = message;
    _url = null;
    _pin = null;
  }

  Future<void> stop() async {
    await _server?.stop();
    _status = ServerStatus.stopped;
    _url = null;
    _pin = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _networkSub.cancel();
    _serverSub?.cancel();
    _server?.dispose();
    _events.close();
    super.dispose();
  }
}
