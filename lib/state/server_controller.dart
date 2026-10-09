import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/log.dart';
import '../server/server_event.dart';
import '../services/network_service.dart';
import '../services/server_service.dart';
import '../services/storage_service.dart';

enum ServerStatus { stopped, starting, running, error }

typedef ServerFactory = ServerService Function(StorageService storage);

ServerService defaultServerFactory(StorageService storage) =>
    ServerService(storage: storage);

/// UI'nin tek durum kaynağı.
class ServerController extends ChangeNotifier {
  ServerController({
    required NetworkService network,
    required this.storage,
    this.createServer = defaultServerFactory,
  }) {
    _networkSub = network.watch().listen((result) {
      _network = result;
      _notify();
    });
    unawaited(refreshFiles());
  }

  final StorageService storage;
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
  List<StoredFile> _files = const [];
  String? _lastText;
  bool _disposed = false;

  ServerStatus get status => _status;
  String? get url => _url;
  String? get pin => _pin;
  String? get errorMessage => _errorMessage;
  Stream<ServerEvent> get events => _events.stream;

  /// Paylaşım klasöründeki dosyalar (PC'den gelen + telefondan eklenen).
  List<StoredFile> get files => _files;

  /// PC'den gelen son metin; banner kapatılınca null.
  String? get lastText => _lastText;

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
      final server = _server ??= createServer(storage);
      _serverSub ??= server.events.listen(_onServerEvent);
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
    _notify();
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
    _notify();
  }

  void _onServerEvent(ServerEvent event) {
    switch (event) {
      case TextReceived(:final text):
        _lastText = text;
        _notify();
      case FileUploaded() || FileDeleted():
        unawaited(refreshFiles());
      case ServerErrorEvent():
        break;
    }
    if (!_events.isClosed) _events.add(event);
  }

  void clearText() {
    _lastText = null;
    _notify();
  }

  Future<void> refreshFiles() async {
    try {
      _files = await storage.list();
      _notify();
    } catch (e) {
      Log.d('Files', 'liste hata: $e');
    }
  }

  File fileFor(String name) => storage.resolve(name, strict: true);

  /// Telefondaki dosyayı siler; dosya yoksa false.
  Future<bool> deleteFile(String name) async {
    final deleted = await storage.delete(name);
    Log.d('Files', 'phone delete name=$name ok=$deleted');
    await refreshFiles();
    return deleted;
  }

  /// Telefondan seçilen dosyayı paylaşım klasörüne akışla kopyalar (PC
  /// listesinde görünür). Kaydedilen adı döner.
  Future<String> importFile(String name, Stream<List<int>> data) async {
    final saved = await storage.saveStream(
      name,
      data,
      maxBytes: AppConstants.maxFileBytes,
    );
    Log.d('Files', 'import name=${saved.name} bytes=${saved.bytes}');
    await refreshFiles();
    return saved.name;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _networkSub.cancel();
    _serverSub?.cancel();
    _server?.dispose();
    _events.close();
    super.dispose();
  }
}
