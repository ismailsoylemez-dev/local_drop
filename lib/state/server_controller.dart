import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/errors.dart';
import '../core/log.dart';
import '../server/server_event.dart';
import '../services/background_service.dart';
import '../services/network_service.dart';
import '../services/server_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/storage_target.dart';

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
    this.background,
    this.settings,
    this.mediaStore,
  }) {
    _networkSub = network.watch().listen((result) {
      _network = result;
      _notify();
    });
    _backgroundSub = background?.events.listen(_onBackgroundEvent);
    unawaited(refreshFiles());
    unawaited(_checkDownloadsSupport());
  }

  final StorageService storage;
  final ServerFactory createServer;

  /// null → ön plan servisi yok (testler).
  final BackgroundService? background;
  final SettingsService? settings;
  final MediaStoreAdapter? mediaStore;
  StreamSubscription<BackgroundEvent>? _backgroundSub;
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
  String? _notice;
  bool _downloadsSupported = false;
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

  /// Sunucu çalışırken gösterilen uyarı (bildirim izni yok vb.).
  String? get notice => _notice;

  SaveLocation get saveLocation =>
      settings?.saveLocation ?? SaveLocation.appFolder;

  /// İndirilenler seçeneği (Android 10+).
  bool get downloadsSupported => _downloadsSupported;

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
      await _startBackground('${network.ip}:$port');
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

  Future<void> _startBackground(String address) async {
    final bg = background;
    if (bg == null) return;
    try {
      final granted = await bg.ensureNotificationPermission();
      final error = await bg.start(address);
      _notice =
          error ??
          (granted
              ? null
              : 'Bildirim izni yok: sunucu çalışıyor ama ekran kapanınca '
                    'sistem durdurabilir.');
    } catch (e) {
      Log.d('Fgs', 'start hata: $e');
      _notice = 'Arka plan servisi başlatılamadı';
    }
  }

  Future<void> _onBackgroundEvent(BackgroundEvent event) async {
    switch (event) {
      case BackgroundEvent.stopPressed:
        Log.d('Fgs', 'stop by notification');
        await stop();
      case BackgroundEvent.timeout:
        Log.d('Fgs', 'timeout');
        await stop();
        _status = ServerStatus.error;
        _errorMessage = 'Süre doldu, tekrar başlat';
        _notify();
    }
  }

  Future<void> _checkDownloadsSupport() async {
    try {
      _downloadsSupported = await mediaStore?.isSupported() ?? false;
      _notify();
    } catch (e) {
      Log.d('Storage', 'downloads desteği bilinmiyor: $e');
    }
  }

  Future<void> setSaveLocation(SaveLocation value) async {
    final s = settings;
    if (s == null) return;
    await s.setSaveLocation(value);
    Log.d('Settings', 'saveLocation=${value.name}');
    _notify();
  }

  Future<void> stop() async {
    await _server?.stop();
    try {
      await background?.stop();
    } catch (e) {
      Log.d('Fgs', 'stop hata: $e');
    }
    _notice = null;
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
    _backgroundSub?.cancel();
    _serverSub?.cancel();
    _server?.dispose();
    _events.close();
    super.dispose();
  }
}
